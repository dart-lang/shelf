// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:shelf/shelf.dart';
import 'constants.dart';

/// Serializes a [Response] directly to a [Socket].
final class RawShelfResponseSerializer {
  static final Uint8List _crlf = Uint8List.fromList([charCr, charLf]);
  static final Uint8List _chunkedEnd = Uint8List.fromList([
    48, // '0'
    charCr, charLf,
    charCr, charLf,
  ]);

  static Future<void> writeResponse(
    Response response,
    Socket socket, {
    required bool keepAlive,
  }) async {
    final headers = Map<String, List<String>>.from(response.headersAll);

    // Determine if we need chunked encoding
    final hasContentLength =
        headers.containsKey('content-length') || response.contentLength != null;
    final isChunked = !hasContentLength;

    if (isChunked) {
      headers['transfer-encoding'] = ['chunked'];
    } else if (!headers.containsKey('content-length') &&
        response.contentLength != null) {
      headers['content-length'] = [response.contentLength.toString()];
    }

    if (!headers.containsKey('connection')) {
      headers['connection'] = [keepAlive ? 'keep-alive' : 'close'];
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
    if (isChunked) {
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
