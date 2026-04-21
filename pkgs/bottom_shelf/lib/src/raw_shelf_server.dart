// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:stream_channel/stream_channel.dart';

import 'body_stream.dart';
import 'lazy_byte_header_map.dart';
import 'raw_http_parser.dart';
import 'raw_shelf_response_serializer.dart';
import 'typed_headers.dart';

/// A high-performance Shelf server that uses raw [ServerSocket]s.
final class RawShelfServer {
  final Handler _handler;
  final ServerSocket _serverSocket;

  RawShelfServer._(this._handler, this._serverSocket);

  int get port => _serverSocket.port;
  InternetAddress get address => _serverSocket.address;

  static Future<RawShelfServer> serve(
    Handler handler,
    Object address,
    int port, {
    int backlog = 0,
    bool shared = false,
  }) async {
    final serverSocket = await ServerSocket.bind(
      address,
      port,
      backlog: backlog,
      shared: shared,
    );
    final server = RawShelfServer._(handler, serverSocket);
    serverSocket.listen(server._handleConnection);
    return server;
  }

  void _handleConnection(Socket socket) {
    final parser = RawHttpParser();
    BodyController? bodyController;

    // We use a Completer to signal when we're ready for the next request in
    // keep-alive. This ensures we don't start parsing the next request
    // until the current one is fully processed (including response).
    var readyForNextRequest = Completer<void>()..complete();

    StreamSubscription<Uint8List>? subscription;
    StreamController<Uint8List>? hijackController;
    var isHijacked = false;
    var isDestroyed = false;
    var clientClosed = false;

    void destroy() {
      if (isDestroyed) return;
      isDestroyed = true;
      subscription?.cancel();
      socket.destroy();
      bodyController?.close();
      if (!readyForNextRequest.isCompleted) {
        readyForNextRequest.completeError(
          const HttpException('Socket destroyed'),
        );
        readyForNextRequest.future.catchError((_) {});
      }
    }

    void processData(Uint8List data) {
      if (isHijacked) {
        hijackController?.add(data);
        return;
      }
      if (isDestroyed || clientClosed) return;

      try {
        var currentData = data;
        while (currentData.isNotEmpty) {
          if (isHijacked) {
            hijackController?.add(currentData);
            return;
          }
          if (isDestroyed) return;

          if (bodyController != null) {
            currentData = bodyController!.add(currentData);
            if (currentData.isNotEmpty || bodyController!.isDone) {
              bodyController = null;
              continue;
            }
            break;
          }

          if (!readyForNextRequest.isCompleted) {
            // We shouldn't receive data while processing a request
            // unless it's pipelined data. Pause and wait.
            subscription?.pause(
              readyForNextRequest.future.then((_) {
                if (!isDestroyed && !clientClosed) {
                  processData(currentData);
                }
              }),
            );
            return;
          }

          if (parser.process(currentData)) {
            readyForNextRequest = Completer<void>();
            final bodyDone = Completer<void>();

            final typedHeaders = TypedHeaders(parser.headerSlices);

            if (typedHeaders.hasConflictingBodyHeaders) {
              socket.add(
                utf8.encode(
                  'HTTP/1.1 400 Bad Request\r\nConnection: close\r\n\r\n',
                ),
              );
              destroy();
              return;
            }

            final host = typedHeaders.host ?? 'localhost';

            var uri = Uri.parse(parser.url!);
            if (!uri.hasScheme) {
              uri = Uri.parse('http://$host${parser.url!}');
            }

            final consumedInHeaders = parser.consumedInLastChunk;
            final remainingInChunk = Uint8List.sublistView(
              currentData,
              consumedInHeaders,
            );

            final contentLength = typedHeaders.contentLength ?? 0;

            Stream<Uint8List> requestBody;
            if (typedHeaders.isChunked) {
              bodyController = ChunkedBodyController(() {
                if (!bodyDone.isCompleted) bodyDone.complete();
              });
              requestBody = bodyController!.stream;
              currentData = bodyController!.add(remainingInChunk);
            } else if (contentLength > 0) {
              bodyController = FixedLengthBodyController(contentLength, () {
                if (!bodyDone.isCompleted) bodyDone.complete();
              });
              requestBody = bodyController!.stream;
              currentData = bodyController!.add(remainingInChunk);
            } else {
              requestBody = const Stream<Uint8List>.empty();
              currentData = remainingInChunk;
              bodyDone.complete();
            }

            final thisRequestBodyController = bodyController;
            final capturedDataAtHijack = currentData;

            if (bodyController?.isDone ?? false) {
              bodyController = null;
            }

            var finalHeaderSlices = parser.headerSlices;
            if (typedHeaders.isChunked) {
              finalHeaderSlices = finalHeaderSlices
                  .where((s) => !s.key.matches('transfer-encoding'))
                  .toList();
            }

            final request = Request(
              parser.method!,
              uri,
              protocolVersion: parser.version!,
              headers: LazyByteHeaderMap(finalHeaderSlices),
              body: requestBody,
              context: {'shelf.raw.headers': typedHeaders},
              onHijack: (void Function(StreamChannel<List<int>>) callback) {
                isHijacked = true;
                hijackController = StreamController<Uint8List>(sync: true);

                if (thisRequestBodyController != null) {
                  final buffered = thisRequestBodyController.takeBufferedData();
                  if (buffered.isNotEmpty) {
                    hijackController!.add(buffered);
                  }
                }

                if (capturedDataAtHijack.isNotEmpty) {
                  hijackController!.add(capturedDataAtHijack);
                }
                callback(StreamChannel(hijackController!.stream, socket));
              },
            );

            unawaited(() async {
              try {
                final response = await _handler(request);
                if (isHijacked) return;

                final keepAlive = typedHeaders.isKeepAlive(parser.version!);

                await RawShelfResponseSerializer.writeResponse(
                  response,
                  socket,
                  keepAlive: keepAlive,
                );

                parser.reset();

                if (keepAlive) {
                  await bodyDone.future;
                  if (!readyForNextRequest.isCompleted) {
                    readyForNextRequest.complete();
                  }
                } else {
                  await socket.close();
                }
              } on HijackException {
                // Handled
              } catch (e) {
                if (!isHijacked && !isDestroyed) {
                  // Phase 4 covers proper logging.
                  // Use print for now to pass tests.
                  print('Error in handler: $e');
                  destroy();
                }
              }
            }());

            if (bodyController != null || isHijacked) {
              break;
            }
          } else {
            break;
          }
        }
      } catch (e) {
        if (!isHijacked && !isDestroyed) {
          print('Error handling connection: $e');
          destroy();
        }
      }
    }

    subscription = socket.listen(
      processData,
      onError: (Object e) {
        if (isHijacked) {
          hijackController?.addError(e);
        } else {
          destroy();
        }
      },
      onDone: () {
        if (isHijacked) {
          hijackController?.close();
        } else {
          clientClosed = true;
          bodyController?.close();
        }
      },
      cancelOnError: true,
    );
  }

  Future<void> close() => _serverSocket.close();
}
