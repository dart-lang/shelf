// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'package:bottom_shelf/src/raw_shelf_server.dart';
import 'package:shelf/shelf.dart';

void main() async {
  Response handler(Request request) => Response.ok(request.read());

  final server = await RawShelfServer.serve(handler, '127.0.0.1', 0);
  print('SERVER_PORT=${server.port}');

  // Keep alive
  await Completer<void>().future;
}
