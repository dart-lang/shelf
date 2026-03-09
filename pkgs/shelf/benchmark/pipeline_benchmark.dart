// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:shelf/shelf.dart';

void main() async {
  final handler = const Pipeline()
      .addMiddleware((innerHandler) => (request) => innerHandler(request))
      .addMiddleware((innerHandler) => (request) => innerHandler(request))
      .addMiddleware((innerHandler) => (request) => innerHandler(request))
      .addMiddleware((innerHandler) => (request) => innerHandler(request))
      .addMiddleware((innerHandler) => (request) => innerHandler(request))
      .addHandler((request) => Response.ok('hello world'));

  final url = Uri.http('localhost:8080', '/');
  final headers = {
    'Accept': 'text/html',
    'User-Agent': 'Dart/3.0',
    'X-Forwarded-For': '192.168.1.1',
  };

  print('Warming up...');
  for (var i = 0; i < 10000; i++) {
    final request = Request('GET', url, headers: headers);
    await handler(request);
  }

  print('Running benchmark...');
  final sw = Stopwatch()..start();
  const iterations = 1000000;
  for (var i = 0; i < iterations; i++) {
    final request = Request('GET', url, headers: headers);
    await handler(request);
  }
  sw.stop();
  print('Total time: ${sw.elapsedMilliseconds} ms');
  print(
      'Req/sec: ${(iterations / sw.elapsedMicroseconds * 1000000).toStringAsFixed(2)}');
}
