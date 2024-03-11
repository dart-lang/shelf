// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:args/args.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

void main(List<String> args) async {
  final parser = _getParser();

  String address;
  int port;
  try {
    final result = parser.parse(args);
    address = result['address'] as String;
    port = int.parse(result['port'] as String);
  } on FormatException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln(parser.usage);
    // http://linux.die.net/include/sysexits.h
    // #define EX_USAGE	64	/* command line usage error */
    exit(64);
  }

  var handler =
      const Pipeline().addMiddleware(logRequests()).addHandler(_echoRequest);

  var server = await shelf_io.serve(handler, address, port);

  // Enable content compression
  server.autoCompress = true;

  print('Serving at http://${server.address.host}:${server.port}');
}

Response _echoRequest(Request request) =>
    Response.ok('Request for "${request.url}"');

ArgParser _getParser() => ArgParser()
  ..addOption('port', abbr: 'p', defaultsTo: '8080', help: 'Port to listen on')
  ..addOption('address',
      abbr: 'a', defaultsTo: 'localhost', help: 'Address to listen on');
