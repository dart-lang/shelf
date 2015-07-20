// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library shelf_static.example;

import 'dart:io';
import 'package:args/args.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

void main(List<String> args) {
  var result = _getParser().parse(args);
  var logging = result['logging'];

  if (!FileSystemEntity.isFileSync('example/example_server.dart')) {
    throw new StateError('Server expects to be started the '
        'root of the project.');
  }
  var pipeline = const shelf.Pipeline();

  if (logging) {
    pipeline = pipeline.addMiddleware(shelf.logRequests());
  }

  var handler = pipeline.addHandler(
      createStaticHandler('example/files', defaultDocument: 'index.html'));

  io.serve(handler, 'localhost', 8080).then((server) {
    print('Serving at http://${server.address.host}:${server.port}');
  });
}

ArgParser _getParser() => new ArgParser()
  ..addFlag('logging', abbr: 'l', defaultsTo: true, negatable: true);
