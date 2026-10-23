// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Shared echo and cookie inspection handler for `Http11Probe` server targets,
/// inspired by
/// https://github.com/MDA2AV/Http11Probe/blob/main/src/Servers/EffinitiveServer/Program.cs.
library;

import 'package:shelf/shelf.dart';

/// Standard [Handler] used by compliance probe echo servers.
final Handler handler = const Pipeline()
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
  final sb = StringBuffer();
  for (final rawCookie in cookieHeader.split(';')) {
    final cookie = rawCookie.trim();
    if (cookie.isEmpty) continue;
    final equalsIndex = cookie.indexOf('=');
    if (equalsIndex >= 0) {
      final key = cookie.substring(0, equalsIndex);
      final value = cookie.substring(equalsIndex + 1);
      sb.write('$key=$value\r\n');
    } else {
      sb.write('$cookie=\r\n');
    }
  }
  return Response.ok(sb.toString());
}
