// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:shelf/shelf.dart';
import 'constants.dart';

/// Serializes a [Response] directly to a [Socket].
final class RawShelfResponseSerializer {
  static final Uint8List _crlf = Uint8List.fromList([$Chars.cr, $Chars.lf]);
  static final Uint8List _chunkedEnd = Uint8List.fromList([
    $Chars.zero,
    $Chars.cr,
    $Chars.lf,
    $Chars.cr,
    $Chars.lf,
  ]);

  static int _cachedSecond = 0;
  static String _cachedDateStr = '';

  static String _getCachedDate() {
    final now = DateTime.now();
    final second = now.millisecondsSinceEpoch ~/ 1000;
    if (second != _cachedSecond) {
      _cachedSecond = second;
      _cachedDateStr = HttpDate.format(now);
    }
    return _cachedDateStr;
  }

  static Future<void> writeResponse(
    Response response,
    Socket socket, {
    required bool keepAlive,
    required String requestMethod,
    String? poweredBy,
  }) async {
    var hasContentLength = false;
    var hasTransferEncoding = false;
    var hasConnection = false;
    var hasDate = false;
    var hasPoweredBy = false;

    final headerBuffer = StringBuffer();
    headerBuffer.write(
      'HTTP/1.1 ${response.statusCode} ${_getStatusPhrase(response.statusCode)}\r\n',
    );

    response.headersAll.forEach((key, values) {
      if (values.isNotEmpty) {
        final lower = key.toLowerCase();
        if (lower == 'content-length') {
          hasContentLength = true;
        } else if (lower == 'transfer-encoding') {
          hasTransferEncoding = true;
        } else if (lower == 'connection') {
          hasConnection = true;
        } else if (lower == 'date') {
          hasDate = true;
        } else if (lower == 'x-powered-by') {
          hasPoweredBy = true;
        }
        headerBuffer.write('$key: ${values.join(', ')}\r\n');
      }
    });

    final isChunked = !hasContentLength && response.contentLength == null;

    if (isChunked) {
      if (!hasTransferEncoding) {
        headerBuffer.write('Transfer-Encoding: chunked\r\n');
      }
    } else if (!hasContentLength && response.contentLength != null) {
      headerBuffer.write('Content-Length: ${response.contentLength}\r\n');
    }

    if (!hasConnection) {
      headerBuffer.write(
        'Connection: ${keepAlive ? 'keep-alive' : 'close'}\r\n',
      );
    }

    if (poweredBy != null && !hasPoweredBy) {
      headerBuffer.write('X-Powered-By: $poweredBy\r\n');
    }

    if (!hasDate) {
      headerBuffer.write('Date: ${_getCachedDate()}\r\n');
    }

    headerBuffer.write('\r\n');

    final headerBytes = utf8.encode(headerBuffer.toString());

    if (requestMethod == 'HEAD' || response.contentLength == 0) {
      socket.add(headerBytes);
      if (requestMethod == 'HEAD') {
        await response.read().listen((_) {}).asFuture<void>();
      }
    } else {
      var isFirst = true;
      await for (final chunk in response.read()) {
        if (chunk.isEmpty) continue;
        if (isFirst) {
          isFirst = false;
          final builder = BytesBuilder(copy: false);
          builder.add(headerBytes);
          if (isChunked) {
            builder.add(utf8.encode('${chunk.length.toRadixString(16)}\r\n'));
            builder.add(chunk);
            builder.add(_crlf);
          } else {
            builder.add(chunk);
          }
          socket.add(builder.takeBytes());
        } else {
          if (isChunked) {
            final builder = BytesBuilder(copy: false);
            builder.add(utf8.encode('${chunk.length.toRadixString(16)}\r\n'));
            builder.add(chunk);
            builder.add(_crlf);
            socket.add(builder.takeBytes());
          } else {
            socket.add(chunk);
          }
        }
      }

      if (isFirst) {
        socket.add(headerBytes);
      }

      if (isChunked) {
        socket.add(_chunkedEnd);
      }
    }

    await socket.flush();
  }

  static String _getStatusPhrase(int statusCode) => switch (statusCode) {
    200 => 'OK',
    201 => 'Created',
    204 => 'No Content',
    301 => 'Moved Permanently',
    302 => 'Found',
    304 => 'Not Modified',
    400 => 'Bad Request',
    401 => 'Unauthorized',
    403 => 'Forbidden',
    404 => 'Not Found',
    500 => 'Internal Server Error',
    _ => 'Unknown',
  };
}
