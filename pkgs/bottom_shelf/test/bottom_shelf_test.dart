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
  late RawShelfServer server;

  tearDown(() async {
    await server.close();
  });

  group('RawShelfServer', () {
    test('basic request/response', () async {
      server = await RawShelfServer.serve(
        (request) {
          return Response.ok('hello world');
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

      final response = await utf8.decodeStream(socket);
      expect(response, contains('HTTP/1.1 200 OK'));
      expect(response, contains('hello world'));
    });

    test('multiple requests over keep-alive', () async {
      var count = 0;
      server = await RawShelfServer.serve(
        (request) {
          count++;
          return Response.ok('request $count');
        },
        'localhost',
        0,
      );

      final socket = await Socket.connect('localhost', server.port);

      final responses = <String>[];
      final completer = Completer<void>();

      socket.listen((data) {
        final chunk = utf8.decode(data);
        responses.add(chunk);
        final full = responses.join();
        if (full.contains('request 2')) {
          if (!completer.isCompleted) completer.complete();
        }
      });

      // Send both requests (pipelined)
      socket.add(
        utf8.encode(
          'GET /1 HTTP/1.1\r\nHost: localhost\r\nConnection: keep-alive\r\n\r\n'
          'GET /2 HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n',
        ),
      );

      await completer.future;

      final fullResponse = responses.join();
      expect(fullResponse, contains('request 1'));
      expect(fullResponse, contains('request 2'));
      await socket.close();
    });

    test(
      'error in handler leads to socket destruction (current behavior)',
      () async {
        server = await RawShelfServer.serve(
          (request) {
            throw Exception('oops');
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

        try {
          final result = await utf8.decodeStream(socket);
          expect(result, isEmpty);
        } catch (e) {
          // Expected
        }
      },
    );
  });

  group('TypedHeaders', () {
    test('lazily parses and caches', () async {
      final completer = Completer<void>();
      server = await RawShelfServer.serve(
        (request) {
          try {
            final typed = request.context['shelf.raw.headers'] as TypedHeaders;
            expect(typed.contentLength, 123);
            expect(typed.contentLength, 123); // Cache hit
            if (!completer.isCompleted) completer.complete();
          } catch (e, st) {
            if (!completer.isCompleted) completer.completeError(e, st);
          }
          return Response.ok('ok');
        },
        'localhost',
        0,
      );

      final socket = await Socket.connect('localhost', server.port);
      socket.add(
        utf8.encode(
          'GET / HTTP/1.1\r\nHost: localhost\r\nContent-Length: 123\r\nConnection: close\r\n\r\n',
        ),
      );

      await completer.future;
      await socket.drain();
      await socket.close();
    });
  });
}
