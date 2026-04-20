// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';

/// Serializes a [Response] directly to a [Socket].
class RawShelfResponseSerializer {
  static const _charCr = 13;
  static const _charLf = 10;
  static const _crlf = [_charCr, _charLf];

  static Future<void> writeResponse(Response response, Socket socket) async {
    // Write Status Line
    socket.add(utf8.encode(
        'HTTP/1.1 ${response.statusCode} ${_getStatusPhrase(response.statusCode)}\r\n'));

    // Write Headers
    response.headersAll.forEach((key, values) {
      for (var value in values) {
        socket.add(utf8.encode('$key: $value\r\n'));
      }
    });

    // End Headers
    socket.add(_crlf);

    // Write Body
    await socket.addStream(response.read());
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
