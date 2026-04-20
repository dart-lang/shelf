// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
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
    FixedLengthBodyController? bodyController;

    // We use a Completer to signal when we're ready for the next request in
    // keep-alive. This ensures we don't start parsing the next request
    // until the current one is fully processed (including response).
    var readyForNextRequest = Completer<void>()..complete();

    StreamController<Uint8List>? hijackController;
    var isHijacked = false;
    var isDestroyed = false;

    void destroy() {
      if (isDestroyed) return;
      isDestroyed = true;
      socket.destroy();
      bodyController?.close();
      if (!readyForNextRequest.isCompleted) {
        readyForNextRequest.completeError(
          const HttpException('Socket destroyed'),
        );
        // Ensure the error doesn't become an unhandled top-level exception
        readyForNextRequest.future.catchError((_) {});
      }
    }

    socket.listen(
      (data) async {
        if (isHijacked) {
          hijackController?.add(data);
          return;
        }
        if (isDestroyed) return;

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
                // Body is finished, but we might have more data for next
                // request.
                bodyController = null;
                // Continue loop to process currentData as next headers.
                continue;
              }
              break;
            }

            if (!readyForNextRequest.isCompleted) {
              try {
                await readyForNextRequest.future;
              } catch (_) {
                return;
              }
            }

            if (isHijacked) {
              hijackController?.add(currentData);
              return;
            }
            if (isDestroyed) return;

            if (parser.process(currentData)) {
              // Headers are complete
              readyForNextRequest = Completer<void>();
              final bodyDone = Completer<void>();

              final typedHeaders = TypedHeaders(parser.headerSlices);
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
              if (contentLength > 0) {
                bodyController = FixedLengthBodyController(contentLength, () {
                  if (!bodyDone.isCompleted) bodyDone.complete();
                });
                requestBody = bodyController!.stream;
                // Process what's left in the current chunk
                currentData = bodyController!.add(remainingInChunk);
                if (bodyController!.isDone) {
                  bodyController = null;
                }
              } else {
                requestBody = const Stream<Uint8List>.empty();
                currentData = remainingInChunk;
                bodyDone.complete();
              }

              final capturedDataAtHijack = currentData;

              final request = Request(
                parser.method!,
                uri,
                protocolVersion: parser.version!,
                headers: LazyByteHeaderMap(parser.headerSlices),
                body: requestBody,
                context: {'shelf.raw.headers': typedHeaders},
                onHijack: (void Function(StreamChannel<List<int>>) callback) {
                  isHijacked = true;

                  // Create a controller that will receive data from the
                  // socket.listen callback from now on.
                  hijackController = StreamController<Uint8List>(sync: true);

                  // Prepend any data already read but not processed
                  if (capturedDataAtHijack.isNotEmpty) {
                    hijackController!.add(capturedDataAtHijack);
                  }

                  callback(StreamChannel(hijackController!.stream, socket));
                },
              );

              // We don't await the handler here in a way that blocks the
              // socket listener from receiving more body data.
              // Instead, we let the handler run and just manage the
              // readyForNextRequest completer.
              unawaited(() async {
                try {
                  final response = await _handler(request);
                  if (isHijacked || isDestroyed) return;

                  final keepAlive = typedHeaders.isKeepAlive(parser.version!);

                  await RawShelfResponseSerializer.writeResponse(
                    response,
                    socket,
                    keepAlive: keepAlive,
                  );

                  parser.reset();

                  if (keepAlive) {
                    // Wait for body to be fully consumed/drained before next request
                    await bodyDone.future;
                    if (!readyForNextRequest.isCompleted) {
                      readyForNextRequest.complete();
                    }
                  } else {
                    await socket.close();
                  }
                } on HijackException {
                  // Handled
                } catch (e, st) {
                  if (!isHijacked && !isDestroyed) {
                    print('Error in handler: $e\n$st');
                    destroy();
                  }
                }
              }());

              // Break the loop if we are still streaming the body.
              // and wait for next socket data event.
              if (bodyController != null || isHijacked) {
                break;
              }
            } else {
              // Headers incomplete
              break;
            }
          }
        } catch (e, st) {
          if (!isHijacked && !isDestroyed) {
            print('Error handling connection: $e\n$st');
            destroy();
          }
        }
      },
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
          destroy();
        }
      },
      cancelOnError: true,
    );
  }

  Future<void> close() => _serverSocket.close();
}
