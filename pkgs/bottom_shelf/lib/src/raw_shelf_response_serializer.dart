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

    // Write Status Line
    socket.add(
      utf8.encode(
        'HTTP/1.1 ${response.statusCode} ${_getStatusPhrase(response.statusCode)}\r\n',
      ),
    );

    // Write Headers
    headers.forEach((key, values) {
      if (values.isNotEmpty) {
        socket.add(utf8.encode('$key: ${values.join(', ')}\r\n'));
      }
    });

    // End Headers
    socket.add(_crlf);

    // Write Body
    if (requestMethod == 'HEAD') {
      // Drain the stream to avoid leaks
      await response.read().listen((_) {}).asFuture<void>();
    } else if (isChunked) {
      await for (final chunk in response.read()) {
        if (chunk.isEmpty) continue;
        // Hex size
        socket.add(utf8.encode('${chunk.length.toRadixString(16)}\r\n'));
        socket.add(chunk);
        socket.add(_crlf);
      }
      socket.add(_chunkedEnd);
    } else {
      await for (final chunk in response.read()) {
        socket.add(chunk);
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
