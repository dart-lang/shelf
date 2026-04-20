import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bottom_shelf/bottom_shelf.dart';
import 'package:shelf/shelf.dart';

void main() async {
  final size = 10 * 1024 * 1024; // 10MB
  final data = Uint8List(size);

  final server = await RawShelfServer.serve(
    (request) async {
      final sw = Stopwatch()..start();
      final body = await request.read().toList();
      sw.stop();
      final totalBytes = body.fold<int>(0, (a, b) => a + b.length);
      return Response.ok(
        'Read $totalBytes bytes in ${sw.elapsedMilliseconds}ms',
      );
    },
    'localhost',
    0,
  );

  print('Benchmarking 10MB upload...');

  final socket = await Socket.connect('localhost', server.port);
  socket.add(
    utf8.encode(
      'POST / HTTP/1.1\r\nHost: localhost\r\nContent-Length: $size\r\nConnection: close\r\n\r\n',
    ),
  );

  final sw = Stopwatch()..start();
  // Send in 8KB chunks
  for (var i = 0; i < size; i += 8192) {
    socket.add(Uint8List.sublistView(data, i, i + 8192));
    // Small delay to ensure they are processed as separate events if possible
    await Future<void>.delayed(Duration.zero);
  }

  final response = await utf8.decodeStream(socket);
  sw.stop();

  print(response.split('\r\n\r\n').last);
  print('Total client-side time: ${sw.elapsedMilliseconds}ms');

  final mb = size / (1024 * 1024);
  final sec = sw.elapsedMilliseconds / 1000;
  print('Throughput: ${(mb / sec).toStringAsFixed(2)} MB/s');

  await server.close();
}
