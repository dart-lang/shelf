// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bottom_shelf/bottom_shelf.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('HTTP Protocol', () {
    test('HTTP/1.0 support (defaults to close)', () async {
      final server = await RawShelfServer.serve(
        (request) {
          expect(request.protocolVersion, '1.0');
          return Response.ok('v1.0');
        },
        'localhost',
        0,
      );
      addTearDown(server.close);

      final socket = await Socket.connect('localhost', server.port);
      addTearDown(socket.close);
      socket.add(utf8.encode('GET / HTTP/1.0\r\nHost: localhost\r\n\r\n'));

      final response = await utf8.decodeStream(socket);
      expect(response, contains('v1.0'));
    });

    test('HTTP/1.1 support (defaults to keep-alive)', () async {
      final server = await RawShelfServer.serve(
        (request) {
          expect(request.protocolVersion, '1.1');
          return Response.ok('v1.1');
        },
        'localhost',
        0,
      );
      addTearDown(server.close);

      final socket = await Socket.connect('localhost', server.port);
      addTearDown(socket.close);
      socket.add(utf8.encode('GET / HTTP/1.1\r\nHost: localhost\r\n\r\n'));

      final completer = Completer<String>();
      final chunks = <String>[];
      socket.listen((data) {
        chunks.add(utf8.decode(data));
        if (chunks.join().contains('v1.1')) {
          if (!completer.isCompleted) completer.complete(chunks.join());
        }
      });

      final response = await completer.future;
      expect(response, contains('v1.1'));
    });

    test('All standard methods', () async {
      final methods = ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'];
      var currentMethod = '';

      final server = await RawShelfServer.serve(
        (request) {
          expect(request.method, currentMethod);
          return Response.ok(request.method);
        },
        'localhost',
        0,
      );
      addTearDown(server.close);

      for (var method in methods) {
        currentMethod = method;
        final socket = await Socket.connect('localhost', server.port);
        addTearDown(socket.close);
        socket.add(
          utf8.encode(
            '$method / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n',
          ),
        );
        final response = await utf8.decodeStream(socket);
        expect(response, contains(method));
      }
    });

    test('Request with IPv6 Host header', () async {
      final server = await RawShelfServer.serve(
        (request) {
          expect(request.requestedUri.host, '::1');
          expect(request.requestedUri.port, 8080);
          return Response.ok('ok');
        },
        'localhost',
        0,
      );
      addTearDown(server.close);

      final socket = await Socket.connect('localhost', server.port);
      addTearDown(socket.close);
      socket.add(
        utf8.encode(
          'GET / HTTP/1.1\r\nHost: [::1]:8080\r\nConnection: close\r\n\r\n',
        ),
      );
      final response = await utf8.decodeStream(socket);
      expect(response, contains('200 OK'));
    });

    test('Request with absolute URI in request line', () async {
      final server = await RawShelfServer.serve(
        (request) {
          expect(request.requestedUri.path, '/foo');
          return Response.ok('ok');
        },
        'localhost',
        0,
      );
      addTearDown(server.close);

      final socket = await Socket.connect('localhost', server.port);
      addTearDown(socket.close);
      socket.add(
        utf8.encode(
          'GET http://localhost/foo HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n',
        ),
      );
      final response = await utf8.decodeStream(socket);
      expect(response, contains('200 OK'));
    });

    test('Chunked response encoding', () async {
      final server = await RawShelfServer.serve(
        (request) {
          // Return a stream without content-length
          final stream = Stream.fromIterable([
            'chunk1',
            'chunk2',
          ]).map((s) => utf8.encode(s));
          return Response.ok(stream);
        },
        'localhost',
        0,
      );
      addTearDown(server.close);

      final socket = await Socket.connect('localhost', server.port);
      addTearDown(socket.close);
      socket.add(
        utf8.encode(
          'GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n',
        ),
      );

      final response = await utf8.decodeStream(socket);
      final responseLower = response.toLowerCase();
      expect(responseLower, contains('transfer-encoding: chunked'));
      expect(response, contains('6\r\nchunk1\r\n'));
      expect(response, contains('6\r\nchunk2\r\n'));
      expect(response, contains('0\r\n\r\n'));
    });

    test('Fixed-length response encoding', () async {
      final server = await RawShelfServer.serve(
        (request) => Response.ok('fixed', headers: {'Content-Length': '5'}),
        'localhost',
        0,
      );
      addTearDown(server.close);

      final socket = await Socket.connect('localhost', server.port);
      addTearDown(socket.close);
      socket.add(
        utf8.encode(
          'GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n',
        ),
      );

      final response = await utf8.decodeStream(socket);
      final responseLower = response.toLowerCase();
      expect(responseLower, contains('content-length: 5'));
      expect(responseLower, isNot(contains('transfer-encoding')));
      expect(response, endsWith('\r\n\r\nfixed'));
    });

    test('Split chunked request encoding', () async {
      final server = await RawShelfServer.serve(
        (request) async {
          expect(request.contentLength, isNull);
          final body = await request.readAsString();
          expect(body, 'split chunked body');
          return Response.ok('ok');
        },
        'localhost',
        0,
      );
      addTearDown(server.close);

      final socket = await Socket.connect('localhost', server.port);
      addTearDown(socket.close);

      socket.add(
        utf8.encode(
          'POST / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\nTransfer-Encoding: chunked\r\n\r\n',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      socket.add(utf8.encode('5\r\nsplit\r\n'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      socket.add(utf8.encode('D\r\n chunked body\r\n0\r\n\r\n'));

      final response = await utf8.decodeStream(socket);
      expect(response, contains('200 OK'));
    });
  });

  group('Headers', () {
    test('Case insensitivity', () async {
      final server = await RawShelfServer.serve(
        (request) {
          // Shelf should normalize to lowercase keys if accessed via
          // request.headers
          expect(request.headers['x-upper'], 'value');
          expect(request.headers['X-UPPER'], 'value');
          return Response.ok('ok');
        },
        'localhost',
        0,
      );
      addTearDown(server.close);

      final socket = await Socket.connect('localhost', server.port);
      addTearDown(socket.close);
      socket.add(
        utf8.encode(
          'GET / HTTP/1.1\r\nHost: localhost\r\nX-Upper: value\r\nConnection: close\r\n\r\n',
        ),
      );
      await socket.drain<void>();
    });

    test('Multiple header values', () async {
      final server = await RawShelfServer.serve(
        (request) {
          expect(request.headersAll['x-multi'], ['a', 'b']);
          expect(request.headers['x-multi'], 'a,b');
          return Response.ok('ok');
        },
        'localhost',
        0,
      );
      addTearDown(server.close);

      final socket = await Socket.connect('localhost', server.port);
      addTearDown(socket.close);
      socket.add(
        utf8.encode(
          'GET / HTTP/1.1\r\nHost: localhost\r\nX-Multi: a\r\nX-Multi: b\r\nConnection: close\r\n\r\n',
        ),
      );
      await socket.drain<void>();
    });

    test('Big headers', () async {
      final bigValue = 'x' * 4000;
      final server = await RawShelfServer.serve(
        (request) {
          expect(request.headers, containsPair('x-big', bigValue));
          return Response.ok('ok');
        },
        'localhost',
        0,
      );
      addTearDown(server.close);

      final socket = await Socket.connect('localhost', server.port);
      addTearDown(socket.close);
      socket.add(
        utf8.encode(
          'GET / HTTP/1.1\r\nHost: localhost\r\nX-Big: $bigValue\r\nConnection: close\r\n\r\n',
        ),
      );
      final response = await utf8.decodeStream(socket);
      expect(response, contains('200 OK'));
    });
  });
}
