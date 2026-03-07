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
      final request =
          Request('GET', Uri.parse('http://localhost:8080/small.txt'));
      final response = await handler(request);
      await response.readAsString();
    }

    print('Running small.txt benchmark...');
    var sw = Stopwatch()..start();
    const iterationsSmall = 50000;
    for (var i = 0; i < iterationsSmall; i++) {
      final request =
          Request('GET', Uri.parse('http://localhost:8080/small.txt'));
      final response = await handler(request);
      await response.readAsString();
    }
    sw.stop();
    print('Total time: ${sw.elapsedMilliseconds} ms');
    print(
        'Req/sec (small.txt): ${(iterationsSmall / sw.elapsedMicroseconds * 1000000).toStringAsFixed(2)}');

    print('Warming up large.txt...');
    for (var i = 0; i < 10; i++) {
      final request =
          Request('GET', Uri.parse('http://localhost:8080/large.txt'));
      final response = await handler(request);
      await response.read().drain<void>();
    }

    print('Running large.txt benchmark...');
    sw = Stopwatch()..start();
    const iterationsLarge = 1000;
    for (var i = 0; i < iterationsLarge; i++) {
      final request =
          Request('GET', Uri.parse('http://localhost:8080/large.txt'));
      final response = await handler(request);
      await response.read().drain<void>();
    }
    sw.stop();
    print('Total time: ${sw.elapsedMilliseconds} ms');
    print(
        'Req/sec (large.txt): ${(iterationsLarge / sw.elapsedMicroseconds * 1000000).toStringAsFixed(2)}');
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}
