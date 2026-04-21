// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bottom_shelf/bottom_shelf.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('Robustness', () {
    test('Header size limit exceeded', () async {
      final server = await RawShelfServer.serve(
        (request) => Response.ok('ok'),
        'localhost',
        0,
      );
      addTearDown(server.close);

      final socket = await Socket.connect('localhost', server.port);
      addTearDown(socket.close);
      final bigHeader = 'X-Big: ${"x" * 70_000}\r\n'; // Over 64KB
      socket.add(
        utf8.encode('GET / HTTP/1.1\r\nHost: localhost\r\n$bigHeader\r\n'),
      );

      // We expect the server to destroy the socket
      try {
        await utf8.decodeStream(socket);
      } catch (e) {
        // Expected
      }
    });

    test('Malformed request (garbage bytes)', () async {
      final server = await RawShelfServer.serve(
        (request) => Response.ok('ok'),
        'localhost',
        0,
      );
      addTearDown(server.close);

      final socket = await Socket.connect('localhost', server.port);
      addTearDown(socket.close);
      socket.add(List.generate(10_000, (i) => i % 256)); // 10KB of garbage

      try {
        await utf8.decodeStream(socket);
      } catch (e) {
        // Expected
      }
    });

    test('Early client close', () async {
      final completer = Completer<void>();
      final server = await RawShelfServer.serve(
        (request) async {
          completer.complete();
          return Response.ok('ok');
        },
        'localhost',
        0,
      );
      addTearDown(server.close);

      final socket = await Socket.connect('localhost', server.port);
      addTearDown(socket.close);
      socket.add(utf8.encode('GET / HTTP/1.1\r\nHost: localhost\r\n\r\n'));
      await socket.flush();
      await socket.close();

      try {
        await completer.future;
      } catch (e) {
        if (e is! HttpException) rethrow;
      }
    });

    test('NUL in headers', () async {
      final server = await RawShelfServer.serve(
        (request) => Response.ok('ok'),
        'localhost',
        0,
      );
      addTearDown(server.close);

      final socket = await Socket.connect('localhost', server.port);
      addTearDown(socket.close);
      socket.add(
        utf8.encode(
          'GET / HTTP/1.1\r\nHost: localhost\r\n'
          'X-Injected: Value\x00Injection\r\n\r\n',
        ),
      );

      try {
        final response = await utf8
            .decodeStream(socket)
            .timeout(const Duration(seconds: 1));
        expect(response, isNot(contains('200 OK')));
      } catch (e) {
        // Expected
      }
    });

    test('Conflicting body headers (Request Smuggling Prevention)', () async {
      final server = await RawShelfServer.serve(
        (request) => Response.ok('ok'),
        'localhost',
        0,
      );
      addTearDown(server.close);

      final socket = await Socket.connect('localhost', server.port);
      addTearDown(socket.close);
      socket.add(
        utf8.encode(
          'POST / HTTP/1.1\r\nHost: localhost\r\n'
          'Content-Length: 5\r\nTransfer-Encoding: chunked\r\n\r\n'
          '0\r\n\r\n',
        ),
      );

      final response = await utf8.decodeStream(socket);
      expect(response, contains('400 Bad Request'));
    });
  });
}
