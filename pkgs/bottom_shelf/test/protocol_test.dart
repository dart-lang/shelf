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

    test('204 No Content and 304 Not Modified over keep-alive omit chunked '
        'framing and Content-Length on 204', () async {
      final server = await RawShelfServer.serve(
        (request) {
          if (request.url.path == 'no-content') {
            return Response(
              204,
              headers: {'Content-Length': '0', 'Transfer-Encoding': 'chunked'},
            );
          }
          if (request.url.path == 'not-modified') {
            return Response(304);
          }
          return Response.ok('after-bodyless');
        },
        'localhost',
        0,
      );
      addTearDown(server.close);

      final socket = await Socket.connect('localhost', server.port);
      addTearDown(socket.close);

      socket.add(
        utf8.encode(
          'GET /no-content HTTP/1.1\r\nHost: localhost\r\n\r\n'
          'GET /not-modified HTTP/1.1\r\nHost: localhost\r\n\r\n'
          'GET /next HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n',
        ),
      );

      final response = await utf8.decodeStream(socket);
      expect(response, contains('HTTP/1.1 204 No Content'));
      expect(response, contains('HTTP/1.1 304 Not Modified'));
      expect(response, contains('after-bodyless'));

      final parts = response.split('HTTP/1.1 ');
      final resp204 = parts.firstWhere((p) => p.startsWith('204'));
      final resp304 = parts.firstWhere((p) => p.startsWith('304'));
      expect(resp204.toLowerCase(), isNot(contains('content-length')));
      expect(resp204.toLowerCase(), isNot(contains('transfer-encoding')));
      expect(resp204, isNot(contains('0\r\n\r\n')));
      expect(resp304.toLowerCase(), isNot(contains('transfer-encoding')));
      expect(resp304, isNot(contains('0\r\n\r\n')));
    });

    test('Connection token list (keep-alive, close) and multi-header '
        'Connection honor close', () async {
      final server = await RawShelfServer.serve(
        (request) => Response.ok('closed-ok'),
        'localhost',
        0,
      );
      addTearDown(server.close);

      // 1. Single header with comma-separated tokens: keep-alive, close
      final s1 = await Socket.connect('localhost', server.port);
      addTearDown(s1.close);
      s1.add(
        utf8.encode(
          'GET / HTTP/1.1\r\nHost: localhost\r\n'
          'Connection: keep-alive, close\r\n\r\n',
        ),
      );
      final r1 = await utf8.decodeStream(s1);
      expect(r1.toLowerCase(), contains('connection: close'));
      expect(r1, contains('closed-ok'));

      // 2. Multiple Connection headers where second is close
      final s2 = await Socket.connect('localhost', server.port);
      addTearDown(s2.close);
      s2.add(
        utf8.encode(
          'GET / HTTP/1.1\r\nHost: localhost\r\n'
          'Connection: keep-alive\r\n'
          'Connection: close\r\n\r\n',
        ),
      );
      final r2 = await utf8.decodeStream(s2);
      expect(r2.toLowerCase(), contains('connection: close'));
      expect(r2, contains('closed-ok'));
    });

    test('Leading and trailing SP and HTAB OWS trimming on Content-Length, '
        'Connection, and custom headers', () async {
      final server = await RawShelfServer.serve(
        (request) async {
          expect(request.contentLength, 5);
          expect(request.headers['x-custom'], 'trimmed-val');
          final body = await request.readAsString();
          expect(body, 'hello');
          return Response.ok('ows-ok');
        },
        'localhost',
        0,
      );
      addTearDown(server.close);

      final socket = await Socket.connect('localhost', server.port);
      addTearDown(socket.close);
      socket.add(
        utf8.encode(
          'POST / HTTP/1.1\r\n'
          'Host: \t localhost \t \r\n'
          'Content-Length:\t  5  \t\r\n'
          'Connection: \t close \t \r\n'
          'X-Custom: \t  trimmed-val \t \r\n'
          '\r\n'
          'hello',
        ),
      );
      final response = await utf8.decodeStream(socket);
      expect(response, contains('200 OK'));
      expect(response, contains('ows-ok'));
    });

    test(
      'Leading-zero Content-Length values (00, 05, 0200) are rejected with 400',
      () async {
        final server = await RawShelfServer.serve(
          (request) => Response.ok('should-not-reach'),
          'localhost',
          0,
        );
        addTearDown(server.close);

        for (final badCl in ['00', '05', '0200']) {
          final socket = await Socket.connect('localhost', server.port);
          addTearDown(socket.close);
          socket.add(
            utf8.encode(
              'POST / HTTP/1.1\r\nHost: localhost\r\n'
              'Content-Length: $badCl\r\nConnection: close\r\n\r\n',
            ),
          );
          final response = await utf8.decodeStream(socket);
          expect(
            response,
            contains('400 Bad Request'),
            reason: 'Expected 400 for Content-Length: $badCl',
          );
        }
      },
    );

    test('Strict method tchar and strict HTTP version grammar reject invalid '
        'inputs with 400', () async {
      final server = await RawShelfServer.serve(
        (request) => Response.ok('should-not-reach'),
        'localhost',
        0,
      );
      addTearDown(server.close);

      final badRequests = [
        'G@T / HTTP/1.1\r\nHost: localhost\r\n\r\n',
        ' / HTTP/1.1\r\nHost: localhost\r\n\r\n',
        'GET / http/1.1\r\nHost: localhost\r\n\r\n',
        'GET / HTTP/01.01\r\nHost: localhost\r\n\r\n',
        'GET / HTTP/ 1.1\r\nHost: localhost\r\n\r\n',
        'GET / HTTP/1\r\nHost: localhost\r\n\r\n',
        'GET / HTTP/1.x\r\nHost: localhost\r\n\r\n',
      ];

      for (final req in badRequests) {
        final socket = await Socket.connect('localhost', server.port);
        addTearDown(socket.close);
        socket.add(utf8.encode(req));
        final response = await utf8.decodeStream(socket);
        expect(
          response,
          contains('400 Bad Request'),
          reason: 'Expected 400 for request: ${req.trim()}',
        );
      }
    });
  });
}
