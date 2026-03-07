import 'package:shelf/shelf.dart';

void main() async {
  final handler = const Pipeline()
      .addMiddleware((innerHandler) => (request) => innerHandler(request))
      .addMiddleware((innerHandler) => (request) => innerHandler(request))
      .addMiddleware((innerHandler) => (request) => innerHandler(request))
      .addMiddleware((innerHandler) => (request) => innerHandler(request))
      .addMiddleware((innerHandler) => (request) => innerHandler(request))
      .addHandler((request) => Response.ok('hello world'));

  print('Warming up...');
  for (var i = 0; i < 10000; i++) {
    final request =
        Request('GET', Uri.parse('http://localhost:8080/'), headers: {
      'Accept': 'text/html',
      'User-Agent': 'Dart/3.0',
      'X-Forwarded-For': '192.168.1.1',
    });
    await handler(request);
  }

  print('Running benchmark...');
  final sw = Stopwatch()..start();
  const iterations = 1000000;
  for (var i = 0; i < iterations; i++) {
    final request =
        Request('GET', Uri.parse('http://localhost:8080/'), headers: {
      'Accept': 'text/html',
      'User-Agent': 'Dart/3.0',
      'X-Forwarded-For': '192.168.1.1',
    });
    await handler(request);
  }
  sw.stop();
  print('Total time: ${sw.elapsedMilliseconds} ms');
  print(
      'Req/sec: ${(iterations / sw.elapsedMicroseconds * 1000000).toStringAsFixed(2)}');
}
