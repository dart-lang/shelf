// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bottom_shelf/bottom_shelf.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late RawShelfServer server;

  tearDown(() async {
    await server.close();
  });

  group('Body', () {
    test('Empty body', () async {
      server = await RawShelfServer.serve(
        (request) async {
          final body = await request.readAsString();
          expect(body, isEmpty);
          return Response.ok('ok');
        },
        'localhost',
        0,
      );

      final socket = await Socket.connect('localhost', server.port);
      socket.add(
        utf8.encode(
          'GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n',
        ),
      );
      await socket.drain<void>();
    });

    test('Small body in same chunk', () async {
      server = await RawShelfServer.serve(
        (request) async {
          final body = await request.readAsString();
          expect(body, 'hello');
          return Response.ok('ok');
        },
        'localhost',
        0,
      );

      final socket = await Socket.connect('localhost', server.port);
      socket.add(
        utf8.encode(
          'POST / HTTP/1.1\r\nHost: localhost\r\nContent-Length: 5\r\nConnection: close\r\n\r\nhello',
        ),
      );

      final response = await utf8.decodeStream(socket);
      expect(response, contains('200 OK'));
    });

    test('Body spanning multiple chunks', () async {
      server = await RawShelfServer.serve(
        (request) async {
          final body = await request.readAsString();
          expect(body, 'hello world');
          return Response.ok('ok');
        },
        'localhost',
        0,
      );

      final socket = await Socket.connect('localhost', server.port);
      socket.add(
        utf8.encode(
          'POST / HTTP/1.1\r\nHost: localhost\r\nContent-Length: 11\r\nConnection: close\r\n\r\nhello',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      socket.add(utf8.encode(' world'));

      final response = await utf8.decodeStream(socket);
      expect(response, contains('200 OK'));
    });

    test('Large body with many chunks', () async {
      final size = 1024 * 1024; // 1MB
      final data = Uint8List(size);
      for (var i = 0; i < size; i++) {
        data[i] = i % 256;
      }

      server = await RawShelfServer.serve(
        (request) async {
          final bodyBytes = await request.read().expand((e) => e).toList();
          expect(bodyBytes.length, size);
          expect(Uint8List.fromList(bodyBytes), data);
          return Response.ok('ok');
        },
        'localhost',
        0,
      );

      final socket = await Socket.connect('localhost', server.port);
      socket.add(
        utf8.encode(
          'POST / HTTP/1.1\r\nHost: localhost\r\n'
          'Content-Length: $size\r\nConnection: close\r\n\r\n',
        ),
      );

      // Send in 1KB chunks
      for (var i = 0; i < size; i += 1024) {
        socket.add(Uint8List.sublistView(data, i, i + 1024));
        await Future<void>.delayed(Duration.zero);
      }

      final response = await utf8.decodeStream(socket);
      expect(response, contains('200 OK'));
    });

    test('Unconsumed body in keep-alive', () async {
      var count = 0;
      server = await RawShelfServer.serve(
        (request) async {
          count++;
          if (request.method != 'POST') {
            return Response.internalServerError(
              body: 'Expected POST but got ${request.method}',
            );
          }
          if (count == 1) return Response.ok('A');
          final body = await request.readAsString();
          return Response.ok('B: $body');
        },
        'localhost',
        0,
      );

      final socket = await Socket.connect('localhost', server.port);

      // Request A with body
      socket.add(
        utf8.encode(
          'POST / HTTP/1.1\r\nHost: localhost\r\nContent-Length: 5\r\n\r\nhello',
        ),
      );

      // Give server time to process A and be ready for B
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Request B
      socket.add(
        utf8.encode(
          'POST / HTTP/1.1\r\nHost: localhost\r\nContent-Length: 5\r\nConnection: close\r\n\r\nworld',
        ),
      );

      final response = await utf8.decodeStream(socket);
      expect(response, contains('A'));
      expect(response, contains('200 OK'));
      expect(response, contains('B: world'));
    });

    test('Large unconsumed body in keep-alive', () async {
      final largeSize = 1024 * 1024; // 1MB
      server = await RawShelfServer.serve(
        (request) async {
          if (request.url.path == 'a') return Response.ok('A');
          final body = await request.readAsString();
          return Response.ok('B: $body');
        },
        'localhost',
        0,
      );

      final socket = await Socket.connect('localhost', server.port);

      // Request A with large body
      socket.add(
        utf8.encode(
          'POST /a HTTP/1.1\r\nHost: localhost\r\nContent-Length: $largeSize\r\n\r\n',
        ),
      );

      // Send large body in chunks
      final chunk = Uint8List(8192);
      for (var i = 0; i < largeSize; i += 8192) {
        socket.add(chunk);
        await Future<void>.delayed(Duration.zero);
      }

      // Request B
      socket.add(
        utf8.encode(
          'POST /b HTTP/1.1\r\nHost: localhost\r\nContent-Length: 5\r\nConnection: close\r\n\r\nworld',
        ),
      );

      final response = await utf8.decodeStream(socket);
      expect(response, contains('A'));
      expect(response, contains('B: world'));
    });
  });
}
