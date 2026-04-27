// Copyright (c) 2026, the Shelf project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:_shelf_compliance/echo_handler.dart';
import 'package:bottom_shelf/bottom_shelf.dart';

void main(List<String> args) async {
  // Bind to 127.0.0.1 to avoid resolution issues
  final server = await RawShelfServer.serve(
    handler,
    '127.0.0.1',
    0,
    bodyTimeout: const Duration(seconds: 3),
  );
  print('Serving at port: ${server.port}');
}
