// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:args/args.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_proxy/shelf_proxy.dart';

Future<void> main(List<String> args) async {
  final parser = _getParser();

  String address;
  int port;
  String targetAddress;
  try {
    final result = parser.parse(args);
    address = result['address'] as String;
    port = int.parse(result['port'] as String);
    targetAddress = result['targetAddress'] as String;
  } on FormatException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln(parser.usage);
    // http://linux.die.net/include/sysexits.h
    // #define EX_USAGE	64	/* command line usage error */
    exit(64);
  }

  final server = await shelf_io.serve(
    proxyHandler(targetAddress),
    address,
    port,
  );

  print(
      'Proxying for $targetAddress at http://${server.address.host}:${server.port}');
}

ArgParser _getParser() => ArgParser()
  ..addOption('port', abbr: 'p', defaultsTo: '8080', help: 'Port to listen on')
  ..addOption('address',
      abbr: 'a', defaultsTo: 'localhost', help: 'Address to listen on')
  ..addOption('targetAddress',
      abbr: 't', defaultsTo: 'https://dart.dev', help: 'Address proxying for');
