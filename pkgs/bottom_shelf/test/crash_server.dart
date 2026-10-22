// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'package:bottom_shelf/bottom_shelf.dart';
import 'package:bottom_shelf/src/exceptions.dart';
import 'package:shelf/shelf.dart';

void main(List<String> args) async {
  final action = args.isNotEmpty ? args[0] : 'crash';

  ErrorAction? Function(Object, StackTrace)? onAsyncError;
  if (action == 'ignore') {
    onAsyncError = (e, st) => ErrorAction.ignore;
  } else if (action == 'crash') {
    onAsyncError = (e, st) => ErrorAction.crash;
  } else if (action == 'throw') {
    // ignore: only_throw_errors
    onAsyncError = (e, st) => throw e;
  }

  final server = await RawShelfServer.serve(
    (request) {
      Future(() {
        throw StateError('out-of-band error');
      });
      return Response.ok('hello');
    },
    'localhost',
    0,
    onAsyncError: onAsyncError,
  );

  // Print the port so the test knows where to connect
  print('PORT: ${server.port}');
}
