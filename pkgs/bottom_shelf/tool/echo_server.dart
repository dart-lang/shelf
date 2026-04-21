// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'package:bottom_shelf/src/raw_shelf_server.dart';
import 'package:shelf/shelf.dart';

import 'package:stack_trace/stack_trace.dart';

void main() async {
  Response handler(Request request) {
    if (request.url.path == 'echo') {
      final sb = StringBuffer();
      sb.writeln('${request.method} ${request.requestedUri.path} HTTP/1.1');
      request.headers.forEach((key, value) {
        sb.writeln('$key: $value');
      });
      sb.writeln();
      return Response.ok(sb.toString());
    }
    return Response.ok(request.read());
  }

  final server = await RawShelfServer.serve(
    handler,
    '127.0.0.1',
    0,
    onConnectionError:
        (msg, error, st, {required remoteAddress, required remotePort}) {
          final indent = _indent('''
Connection error: $msg
$error
${Trace.from(st).terse}''');

          print('''
$remoteAddress:$remotePort
$indent
''');
        },
  );
  print('SERVER_PORT=${server.port}');

  // Keep alive
  await Completer<void>().future;
}

String _indent(String input) => '  ${input.replaceAll('\n', '\n  ')}';
