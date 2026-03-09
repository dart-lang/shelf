// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';

void main() async {
  final tempDir = Directory.systemTemp.createTempSync('shelf_static_bench_');
  try {
    final smallFile = File('${tempDir.path}/small.txt');
    smallFile.writeAsStringSync('Hello World');

    final largeFile = File('${tempDir.path}/large.txt');
    largeFile.writeAsBytesSync(List.filled(10485760, 0));

    final handler = createStaticHandler(tempDir.path);

    print('Warming up small.txt...');
    for (var i = 0; i < 1000; i++) {
      final request = Request('GET', Uri.http('localhost:8080', 'small.txt'));
      final response = await handler(request);
      await response.readAsString();
    }

    print('Running small.txt benchmark...');
    final smallFileStopwatch = Stopwatch()..start();
    const iterationsSmall = 50000;
    for (var i = 0; i < iterationsSmall; i++) {
      final request = Request('GET', Uri.http('localhost:8080', 'small.txt'));
      final response = await handler(request);
      await response.readAsString();
    }
    smallFileStopwatch.stop();
    print('Total time: ${smallFileStopwatch.elapsedMilliseconds} ms');
    print(
        'Req/sec (small.txt): ${(iterationsSmall / smallFileStopwatch.elapsedMicroseconds * 1000000).toStringAsFixed(2)}');

    print('Warming up large.txt...');
    for (var i = 0; i < 10; i++) {
      final request = Request('GET', Uri.http('localhost:8080', 'large.txt'));
      final response = await handler(request);
      await response.read().drain<void>();
    }

    print('Running large.txt benchmark...');
    final largeFileStopwatch = Stopwatch()..start();
    const iterationsLarge = 1000;
    for (var i = 0; i < iterationsLarge; i++) {
      final request = Request('GET', Uri.http('localhost:8080', 'large.txt'));
      final response = await handler(request);
      await response.read().drain<void>();
    }
    largeFileStopwatch.stop();
    print('Total time: ${largeFileStopwatch.elapsedMilliseconds} ms');
    print(
        'Req/sec (large.txt): ${(iterationsLarge / largeFileStopwatch.elapsedMicroseconds * 1000000).toStringAsFixed(2)}');
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}
