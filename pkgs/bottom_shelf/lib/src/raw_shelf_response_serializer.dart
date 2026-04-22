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

  static Future<void> writeResponse(
    Response response,
    Socket socket, {
    required bool keepAlive,
    required String requestMethod,
    String? poweredBy,
  }) async {
    final headers = Map<String, List<String>>.from(response.headersAll);

    // Determine if we need chunked encoding
    final hasContentLength =
        headers.containsKey($Header.contentLength) ||
        response.contentLength != null;
    final isChunked = !hasContentLength;

    if (isChunked) {
      headers[$Header.transferEncoding] = ['chunked'];
    } else if (!headers.containsKey($Header.contentLength) &&
        response.contentLength != null) {
      headers[$Header.contentLength] = [response.contentLength.toString()];
    }

    if (!headers.containsKey($Header.connection)) {
      headers[$Header.connection] = [keepAlive ? 'keep-alive' : 'close'];
    }

    if (poweredBy != null && !headers.containsKey('x-powered-by')) {
      headers['x-powered-by'] = [poweredBy];
    }

    if (!headers.containsKey($Header.date)) {
      headers[$Header.date] = [HttpDate.format(DateTime.now())];
    }

    final headerBuffer = StringBuffer();
    headerBuffer.write(
      'HTTP/1.1 ${response.statusCode} ${_getStatusPhrase(response.statusCode)}\r\n',
    );

    headers.forEach((key, values) {
      if (values.isNotEmpty) {
        headerBuffer.write('$key: ${values.join(', ')}\r\n');
      }
    });

    headerBuffer.write('\r\n');

    final headerBytes = utf8.encode(headerBuffer.toString());
    var headersSent = false;

    if (requestMethod == 'HEAD') {
      socket.add(headerBytes);
      await response.read().listen((_) {}).asFuture<void>();
      headersSent = true;
    } else {
      await for (final chunk in response.read()) {
        if (chunk.isEmpty) continue;

        if (!headersSent) {
          final builder = BytesBuilder(copy: false);
          builder.add(headerBytes);
          if (isChunked) {
            builder.add(utf8.encode('${chunk.length.toRadixString(16)}\r\n'));
          }
          builder.add(chunk);
          if (isChunked) {
            builder.add(_crlf);
          }
          socket.add(builder.takeBytes());
          headersSent = true;
        } else {
          if (isChunked) {
            socket.add(utf8.encode('${chunk.length.toRadixString(16)}\r\n'));
            socket.add(chunk);
            socket.add(_crlf);
          } else {
            socket.add(chunk);
          }
        }
      }

      if (!headersSent) {
        socket.add(headerBytes);
        headersSent = true;
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
