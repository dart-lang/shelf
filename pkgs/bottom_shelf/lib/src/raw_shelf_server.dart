// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:stream_channel/stream_channel.dart';

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
    StreamSubscription<Uint8List>? subscription;

    // We use a Completer to signal when we're ready for the next request in
    // keep-alive
    var readyForNextRequest = Completer<void>()..complete();

    subscription = socket.listen(
      (data) async {
        try {
          await readyForNextRequest.future;

          var currentData = data;
          while (currentData.isNotEmpty) {
            if (parser.process(currentData)) {
              // Headers are complete
              subscription?.pause();
              readyForNextRequest = Completer<void>();

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

              // TODO: Support chunked transfer encoding for requests.
              // For now, let's just handle bodies by consuming the remaining
              // data and then resuming the subscription if needed.
              // A more robust implementation would use FixedLengthBodyStream.
              // But for POC speed, we'll assume small bodies for now or empty.

              final request = Request(
                parser.method!,
                uri,
                protocolVersion: parser.version!,
                headers: LazyByteHeaderMap(parser.headerSlices),
                // TODO: Real body streaming
                body: contentLength == 0
                    ? const Stream<List<int>>.empty()
                    : Stream.value(remainingInChunk),
                context: {'shelf.raw.headers': typedHeaders},
                onHijack: (void Function(StreamChannel<List<int>>) callback) {
                  subscription?.cancel();
                  callback(StreamChannel(const Stream.empty(), socket));
                },
              );

              try {
                final response = await _handler(request);
                
                var keepAlive = typedHeaders.isKeepAlive(parser.version!);
                
                await RawShelfResponseSerializer.writeResponse(
                  response,
                  socket,
                  keepAlive: keepAlive,
                );

                parser.reset();

                if (keepAlive) {
                  // If we had a body, we should have consumed it.
                  // For now, we assume body was in the same chunk or empty.
                  readyForNextRequest.complete();

                  // If there's more in chunk, loop.
                  // But wait, if we used remainingInChunk for body, we must
                  // skip it.
                  if (contentLength > 0) {
                    // This is tricky without a real body state machine.
                    // For now, just exit loop and wait for next chunk.
                    subscription?.resume();
                    break;
                  }

                  // No body, just continue with any remaining data (pipelining)
                  currentData = remainingInChunk;
                  if (currentData.isEmpty) {
                    subscription?.resume();
                    break;
                  }
                  continue;
                } else {
                  await socket.close();
                  return;
                }
              } on HijackException {
                return;
              }
            } else {
              // Headers incomplete
              return;
            }
          }
        } on HijackException {
          // Handled
        } catch (e, st) {
          print('Error handling request: $e\n$st');
          try {
            socket.destroy();
          } catch (_) {}
        }
      },
      onError: (e) {
        socket.destroy();
      },
      onDone: () {
        socket.destroy();
      },
      cancelOnError: true,
    );
  }

  Future<void> close() => _serverSocket.close();
}
