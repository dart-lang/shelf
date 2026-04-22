// Copyright (c) 2026, the Shelf project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// inspired by https://github.com/MDA2AV/Http11Probe/blob/main/src/Servers/EffinitiveServer/Program.cs
library;

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

void main(List<String> args) async {
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(
        (Request request) =>
            switch ((request.requestedUri.path, request.method)) {
              ('/', 'GET') => Response.ok('OK'),
              ('/', 'POST') => Response.ok(request.read()),
              ('/echo' || '/echo/', _) => _handleEcho(request),
              ('/cookie' || '/cookie/', _) => _handleCookie(request),
              _ => Response.notFound('Not Found'),
            },
      );

  // Bind to 127.0.0.1 to avoid resolution issues
  final server = await shelf_io.serve(handler, '127.0.0.1', 0);
  print('Serving at port: ${server.port}');
}

Response _handleEcho(Request request) {
  final sb = StringBuffer();
  request.headers.forEach((key, value) {
    sb.write('$key: $value\r\n');
  });
  return Response.ok(sb.toString());
}

Response _handleCookie(Request request) {
  final cookieHeader = request.headers['cookie'];
  if (cookieHeader == null) {
    return Response.ok('');
  }
  final cookies = cookieHeader.split(';').map((e) => e.trim()).toList();
  final sb = StringBuffer();
  for (var cookie in cookies) {
    final parts = cookie.split('=');
    if (parts.length >= 2) {
      final key = parts[0];
      final value = parts.sublist(1).join('=');
      sb.write('$key=$value\r\n');
    } else if (cookie.isNotEmpty) {
      sb.write('$cookie=\r\n');
    }
  }
  return Response.ok(sb.toString());
}
