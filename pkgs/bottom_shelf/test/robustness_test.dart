// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bottom_shelf/bottom_shelf.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'test_shared.dart';

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
      final response = await utf8.decodeStream(socket);
      expect(response, isABadRequestResponse);
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

      final response = await utf8.decodeStream(socket);
      expect(response, isABadRequestResponse);
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

      final response = await utf8
          .decodeStream(socket)
          .timeout(const Duration(seconds: 1));
      expect(response, isABadRequestResponse);
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
      expect(response, isABadRequestResponse);
    });

    test('Slowloris Mitigation (Header Timeout)', () async {
      final server = await RawShelfServer.serve(
        (request) => Response.ok('ok'),
        'localhost',
        0,
        headerTimeout: const Duration(milliseconds: 500),
      );
      addTearDown(server.close);

      final socket = await Socket.connect('localhost', server.port);
      addTearDown(socket.close);

      socket.add(utf8.encode('GET / HTTP/1.1\r\n'));
      await socket.flush();

      // Wait longer than the timeout
      await Future<void>.delayed(const Duration(seconds: 1));

      try {
        final response = await utf8.decodeStream(socket);
        expect(response, isEmpty);
      } catch (e) {
        if (e is! SocketException && e is! HttpException) {
          rethrow;
        }
      }
    });

    test('Socket fragmentation (1 byte chunks)', () async {
      final server = await RawShelfServer.serve(
        (request) async {
          expect(request.method, 'POST');
          expect(request.url.path, 'foo');
          expect(request.headers, containsPair('x-custom', 'value'));
          final body = await request.readAsString();
          expect(body, 'hello world');
          return Response.ok('ok');
        },
        'localhost',
        0,
      );
      addTearDown(server.close);

      final socket = await Socket.connect('localhost', server.port);
      addTearDown(socket.close);

      final payload = utf8.encode(
        'POST /foo HTTP/1.1\r\n'
        'Host: localhost\r\n'
        'X-Custom: value\r\n'
        'Transfer-Encoding: chunked\r\n'
        'Connection: close\r\n\r\n'
        '5\r\nhello\r\n'
        '6\r\n world\r\n'
        '0\r\n\r\n',
      );

      for (var byte in payload) {
        socket.add([byte]);
        await socket.flush();
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      final response = await utf8.decodeStream(socket);
      expect(response, contains('200 OK'));
    });

    test('Strict CRLF - rejects bare line feed', () async {
      final server = await RawShelfServer.serve(
        (request) => Response.ok('ok'),
        'localhost',
        0,
      );
      addTearDown(server.close);

      final socket = await Socket.connect('localhost', server.port);
      addTearDown(socket.close);

      // Send request with bare LF (\n instead of \r\n) in headers
      socket.add(
        utf8.encode(
          'GET / HTTP/1.1\r\nHost: localhost\nConnection: close\r\n\r\n',
        ),
      );

      final response = await utf8.decodeStream(socket);
      expect(response, isABadRequestResponse);
    });

    test('Strict CRLF - rejects isolated CR', () async {
      final server = await RawShelfServer.serve(
        (request) => Response.ok('ok'),
        'localhost',
        0,
      );
      addTearDown(server.close);

      final socket = await Socket.connect('localhost', server.port);
      addTearDown(socket.close);

      // Send request with isolated CR (\r not followed by \n)
      socket.add(
        utf8.encode(
          'GET / HTTP/1.1\rHost: localhost\r\nConnection: close\r\n\r\n',
        ),
      );

      final response = await utf8.decodeStream(socket);
      expect(response, isABadRequestResponse);
    });

    test('Header sanitization - rejects control characters in value', () async {
      final server = await RawShelfServer.serve(
        (request) => Response.ok('ok'),
        'localhost',
        0,
      );
      addTearDown(server.close);

      final socket = await Socket.connect('localhost', server.port);
      addTearDown(socket.close);

      // Send request with control character (ASCII 7 - Bell) in header value
      socket.add(
        utf8.encode(
          'GET / HTTP/1.1\r\nHost: localhost\r\nX-Bad: value\x07here\r\nConnection: close\r\n\r\n',
        ),
      );

      final response = await utf8.decodeStream(socket);
      expect(response, isABadRequestResponse);
    });
  });
}
