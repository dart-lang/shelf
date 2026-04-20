// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'constants.dart';

/// Serializes a [Response] directly to a [Socket].
final class RawShelfResponseSerializer {
  static Future<void> writeResponse(
    Response response,
    Socket socket, {
    required bool keepAlive,
  }) async {
    // TODO: Support chunked encoding for responses to avoid buffering the
    // entire body.
    // Consume the body to calculate content length if not provided.
    final bodyBytes = await response.read().expand((chunk) => chunk).toList();
    final length = bodyBytes.length;

    // Write Status Line
    socket.add(
      utf8.encode(
        'HTTP/1.1 ${response.statusCode} ${_getStatusPhrase(response.statusCode)}\r\n',
      ),
    );

    final headers = Map<String, List<String>>.from(response.headersAll);
    if (!headers.containsKey('content-length')) {
      headers['content-length'] = [length.toString()];
    }
    if (!headers.containsKey('connection')) {
      headers['connection'] = [keepAlive ? 'keep-alive' : 'close'];
    }

    // Write Headers
    headers.forEach((key, values) {
      if (values.isNotEmpty) {
        socket.add(utf8.encode('$key: ${values.join(', ')}\r\n'));
      }
    });

    // End Headers
    socket.add(crlf);

    // Write Body
    socket.add(bodyBytes);
    await socket.flush();
  }

  static String _getStatusPhrase(int statusCode) {
    switch (statusCode) {
      case 200:
        return 'OK';
      case 201:
        return 'Created';
      case 204:
        return 'No Content';
      case 301:
        return 'Moved Permanently';
      case 302:
        return 'Found';
      case 304:
        return 'Not Modified';
      case 400:
        return 'Bad Request';
      case 401:
        return 'Unauthorized';
      case 403:
        return 'Forbidden';
      case 404:
        return 'Not Found';
      case 500:
        return 'Internal Server Error';
      default:
        return 'Unknown';
    }
  }
}
