// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:stream_channel/stream_channel.dart';

import 'body_stream.dart';
import 'constants.dart';
import 'exceptions.dart';
import 'lazy_byte_header_map.dart';
import 'raw_http_parser.dart';
import 'raw_shelf_response_serializer.dart';
import 'typed_headers.dart';

/// Starts handling a single HTTP connection for `RawShelfServer`.
void handleHttpConnection({
  required Socket socket,
  required Handler handler,
  Duration? headerTimeout,
  ConnectionErrorCallback? onConnectionError,
  ErrorAction? Function(Object error, StackTrace stackTrace)? onAsyncError,
}) {
  _HttpConnection(
    socket: socket,
    handler: handler,
    headerTimeout: headerTimeout,
    onConnectionError: onConnectionError,
    onAsyncError: onAsyncError,
  ).start();
}

final class _HttpConnection {
  final Socket socket;
  final Handler handler;
  final Duration? headerTimeout;
  final ConnectionErrorCallback? onConnectionError;
  final ErrorAction? Function(Object, StackTrace)? onAsyncError;

  final InternetAddress remoteAddress;
  final int remotePort;

  final _parser = RawHttpParser();
  BodyController? _bodyController;
  var _readyForNextRequest = Completer<void>()..complete();
  StreamSubscription<Uint8List>? _subscription;
  var _forceClose = false;
  Completer<void>? _currentBodyDone;
  StreamController<Uint8List>? _hijackController;
  Timer? _headerTimer;
  var _isHijacked = false;
  var _isDestroyed = false;
  var _clientClosed = false;
  var _responseSent = false;

  _HttpConnection({
    required this.socket,
    required this.handler,
    this.headerTimeout,
    this.onConnectionError,
    this.onAsyncError,
  }) : remoteAddress = socket.remoteAddress,
       remotePort = socket.remotePort;

  void start() {
    _startHeaderTimer();
    _subscription = socket.listen(
      _processData,
      onError: (Object e) {
        if (_isHijacked) {
          _hijackController?.addError(e);
        } else {
          _destroy();
        }
      },
      onDone: () {
        if (_isHijacked) {
          _hijackController?.close();
        } else {
          _clientClosed = true;
          if (_bodyController != null && !_bodyController!.isDone) {
            _bodyController!.addError(
              const BadRequestException('Incomplete body'),
            );
            _bodyController!.close();
            _forceClose = true;
            if (_currentBodyDone != null && !_currentBodyDone!.isCompleted) {
              _currentBodyDone!.complete();
            }
          } else {
            _bodyController?.close();
          }
        }
      },
      cancelOnError: true,
    );
  }

  void _destroy() {
    if (_isDestroyed) return;
    _isDestroyed = true;
    _headerTimer?.cancel();
    _subscription?.cancel();
    socket.destroy();
    _bodyController?.close();
    if (!_readyForNextRequest.isCompleted) {
      _readyForNextRequest.complete();
    }
  }

  void _startHeaderTimer() {
    if (headerTimeout != null && !_isDestroyed && !_clientClosed) {
      _headerTimer?.cancel();
      _headerTimer = Timer(headerTimeout!, _destroy);
    }
  }

  void _cancelHeaderTimer() {
    _headerTimer?.cancel();
    _headerTimer = null;
  }

  void _processData(Uint8List data) {
    if (_isHijacked) {
      _hijackController?.add(data);
      return;
    }
    if (_isDestroyed || _clientClosed) return;

    try {
      var currentData = data;
      while (currentData.isNotEmpty) {
        if (_isHijacked) {
          _hijackController?.add(currentData);
          return;
        }
        if (_isDestroyed) return;

        if (_bodyController != null) {
          currentData = _bodyController!.add(currentData);
          if (currentData.isNotEmpty || _bodyController!.isDone) {
            _bodyController = null;
            continue;
          }
          break;
        }

        if (!_readyForNextRequest.isCompleted) {
          _subscription?.pause(
            _readyForNextRequest.future.then((_) {
              if (!_isDestroyed && !_clientClosed) {
                _processData(currentData);
              }
            }),
          );
          return;
        }

        if (_parser.process(currentData) case final requestHead?) {
          _cancelHeaderTimer();
          _readyForNextRequest = Completer<void>();
          final bodyDone = Completer<void>();

          final typedHeaders = TypedHeaders(requestHead.headerSlices);

          if (typedHeaders.hasConflictingBodyHeaders) {
            socket.add(ErrorResponse.badRequest.bytes);
            _destroy();
            return;
          }

          if (typedHeaders.hasDuplicateHost) {
            socket.add(ErrorResponse.badRequest.bytes);
            _destroy();
            return;
          }

          var contentLengthHeaderCount = 0;
          var clValid = true;
          for (var slice in requestHead.headerSlices) {
            if (slice.key.matches($Header.contentLength)) {
              contentLengthHeaderCount++;
              final value = slice.value.asString();
              if (value.isEmpty ||
                  !value.codeUnits.every((c) => c >= 48 && c <= 57)) {
                clValid = false;
              }
            }
          }

          if (contentLengthHeaderCount > 1 ||
              !clValid ||
              (contentLengthHeaderCount == 1 &&
                  typedHeaders.contentLength == null)) {
            socket.add(ErrorResponse.badRequest.bytes);
            _destroy();
            return;
          }

          var hasTransferEncoding = false;
          var isChunked = false;
          for (var slice in requestHead.headerSlices) {
            if (slice.key.matches($Header.transferEncoding)) {
              hasTransferEncoding = true;
              final value = slice.value.asString().toLowerCase();
              if (value.contains('chunked')) {
                isChunked = true;
              }
            }
          }

          if (hasTransferEncoding && !isChunked) {
            socket.add(ErrorResponse.notImplemented.bytes);
            socket.flush().then((_) {
              socket.close().then((_) => _destroy());
            });
            return;
          }
          if (requestHead.method == 'CONNECT') {
            socket.add(ErrorResponse.methodNotAllowed.bytes);
            socket.flush().then((_) {
              socket.close().then((_) => _destroy());
            });
            return;
          }
          if (requestHead.method == 'CONNECT') {
            socket.add(
              utf8.encode(
                'HTTP/1.1 405 Method Not Allowed\r\nConnection: close\r\n\r\n',
              ),
            );
            socket.flush().then((_) {
              socket.close().then((_) => _destroy());
            });
            return;
          }

          final host = typedHeaders.host;
          if (host != null && (host.contains('@') || host.contains('/'))) {
            socket.add(ErrorResponse.badRequest.bytes);
            socket.flush().then((_) {
              socket.close().then((_) => _destroy());
            });
            return;
          }

          if ((host == null || host.trim().isEmpty) &&
              requestHead.version == '1.1') {
            socket.add(ErrorResponse.badRequest.bytes);
            socket.flush().then((_) {
              socket.close().then((_) => _destroy());
            });
            return;
          }
          final effectiveHost = host ?? 'localhost';

          Uri uri;
          try {
            uri = Uri.parse(requestHead.url);
            if (!uri.hasScheme) {
              final path = requestHead.url.startsWith('/')
                  ? requestHead.url
                  : '/${requestHead.url}';
              uri = Uri.parse('http://$effectiveHost$path');
            }
          } on FormatException catch (e, st) {
            throw BadRequestException(
              'Invalid requested URL: ${e.message}',
              innerException: e,
              innerStack: st,
            );
          }

          final consumedInHeaders = requestHead.consumedInLastChunk;
          final remainingInChunk = Uint8List.sublistView(
            currentData,
            consumedInHeaders,
          );

          final contentLength = typedHeaders.contentLength ?? 0;

          Stream<Uint8List> requestBody;
          if (typedHeaders.isChunked) {
            _bodyController = ChunkedBodyController(
              () {
                if (!bodyDone.isCompleted) bodyDone.complete();
              },
              onPause: () => _subscription?.pause(),
              onResume: () => _subscription?.resume(),
            );
            requestBody = _bodyController!.stream;
            currentData = _bodyController!.add(remainingInChunk);
          } else if (contentLength > 0) {
            _bodyController = FixedLengthBodyController(
              contentLength,
              () {
                if (!bodyDone.isCompleted) bodyDone.complete();
              },
              onPause: () => _subscription?.pause(),
              onResume: () => _subscription?.resume(),
            );
            requestBody = _bodyController!.stream;
            currentData = _bodyController!.add(remainingInChunk);
          } else {
            requestBody = const Stream<Uint8List>.empty();
            currentData = remainingInChunk;
            bodyDone.complete();
          }

          final thisRequestBodyController = _bodyController;
          final capturedDataAtHijack = currentData;

          if (_bodyController?.isDone ?? false) {
            _bodyController = null;
          }

          var finalHeaderSlices = requestHead.headerSlices;
          if (typedHeaders.isChunked) {
            finalHeaderSlices = finalHeaderSlices
                .where((s) => !s.key.matches($Header.transferEncoding))
                .toList();
          }

          void theHijackCallback(
            void Function(StreamChannel<List<int>>) callback,
          ) {
            _isHijacked = true;
            _hijackController = StreamController<Uint8List>(sync: true);

            if (thisRequestBodyController != null) {
              final buffered = thisRequestBodyController.takeBufferedData();
              if (buffered.isNotEmpty) {
                _hijackController!.add(buffered);
              }
            }

            if (capturedDataAtHijack.isNotEmpty) {
              _hijackController!.add(capturedDataAtHijack);
            }
            callback(StreamChannel(_hijackController!.stream, socket));
          }

          Request request;

          try {
            request = Request(
              requestHead.method,
              uri,
              protocolVersion: requestHead.version,
              headers: LazyByteHeaderMap(finalHeaderSlices),
              body: requestBody,
              context: {$Context.rawHeaders: typedHeaders},
              onHijack: theHijackCallback,
            );
          }
          // ignore: avoid_catching_errors
          on ArgumentError catch (e, st) {
            throw BadRequestException(
              'Invalid request parameters',
              innerException: e,
              innerStack: st,
            );
          }

          _dispatchRequest(request, typedHeaders, bodyDone);

          if (_bodyController != null || _isHijacked) {
            break;
          }
        } else {
          break;
        }
      }
    } catch (e, st) {
      if (!_isHijacked && !_isDestroyed) {
        onConnectionError?.call(
          'Error in handler',
          e,
          st,
          remoteAddress: remoteAddress,
          remotePort: remotePort,
        );
        if (e is BadRequestException) {
          socket.add(e.errorResponse.bytes);
          socket.flush().then((_) {
            socket.close().then((_) => _destroy());
          });
        } else {
          _destroy();
        }
      }
    }
  }

  void _dispatchRequest(
    Request request,
    TypedHeaders typedHeaders,
    Completer<void> bodyDone,
  ) {
    _currentBodyDone = bodyDone;
    unawaited(
      runZonedGuarded(
        () async {
          try {
            final response = await handler(request);
            if (_isHijacked) return;

            final keepAlive =
                !_forceClose &&
                typedHeaders.isKeepAlive(request.protocolVersion);

            await RawShelfResponseSerializer.writeResponse(
              response,
              socket,
              keepAlive: keepAlive,
              requestMethod: request.method,
            );
            _responseSent = true;

            _parser.reset();

            if (keepAlive) {
              await bodyDone.future;
              if (_forceClose) {
                await socket.close();
                _destroy();
                return;
              }
              if (!_readyForNextRequest.isCompleted) {
                _readyForNextRequest.complete();
                _startHeaderTimer();
              }
            } else {
              await socket.close();
              _destroy();
            }
          } on HijackException {
            // Handled
          } catch (e, st) {
            if (!_isHijacked && !_isDestroyed && !_responseSent) {
              socket.add(
                utf8.encode(
                  'HTTP/1.1 500 Internal Server Error\r\n'
                  'Connection: close\r\n'
                  'Content-Length: 21\r\n\r\n'
                  'Internal Server Error',
                ),
              );
              onConnectionError?.call(
                'Error in handler',
                e,
                st,
                remoteAddress: remoteAddress,
                remotePort: remotePort,
              );
              unawaited(socket.close().then((_) => _destroy()));
            }
          }
        },
        (e, st) {
          if (e is HijackException) {
            return;
          }
          final action = onAsyncError?.call(e, st);
          if (action == ErrorAction.ignore) {
            if (!_isDestroyed) {
              onConnectionError?.call(
                'Unhandled async error (ignored)',
                e,
                st,
                remoteAddress: remoteAddress,
                remotePort: remotePort,
              );
            }
          } else if (action == ErrorAction.crash) {
            onConnectionError?.call(
              'Crashing server due to async error',
              e,
              st,
              remoteAddress: remoteAddress,
              remotePort: remotePort,
            );
            // ignore: only_throw_errors
            throw e; // Rethrow to parent zone!
          } else {
            // Default or ErrorAction.destroy
            if (!_isHijacked && !_isDestroyed && !_responseSent) {
              socket.add(
                utf8.encode(
                  'HTTP/1.1 500 Internal Server Error\r\n'
                  'Connection: close\r\n'
                  'Content-Length: 21\r\n\r\n'
                  'Internal Server Error',
                ),
              );
            }
            onConnectionError?.call(
              'Error in handler',
              e,
              st,
              remoteAddress: remoteAddress,
              remotePort: remotePort,
            );
            socket.close().then((_) => _destroy());
          }
        },
      ),
    );
  }
}
