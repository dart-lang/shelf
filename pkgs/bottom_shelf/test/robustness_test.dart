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

  group('Robustness', () {
    test('Header size limit exceeded', () async {
      server = await RawShelfServer.serve(
        (request) => Response.ok('ok'),
        'localhost',
        0,
      );

      final socket = await Socket.connect('localhost', server.port);
      final bigHeader = 'X-Big: ${"x" * 70000}\r\n'; // Over 64KB
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
      server = await RawShelfServer.serve(
        (request) => Response.ok('ok'),
        'localhost',
        0,
      );

      final socket = await Socket.connect('localhost', server.port);
      socket.add(List.generate(10000, (i) => i % 256)); // 10KB of garbage

      try {
        await utf8.decodeStream(socket);
      } catch (e) {
        // Expected
      }
    });

    test('Early client close', () async {
      final completer = Completer<void>();
      server = await RawShelfServer.serve(
        (request) async {
          await Future.delayed(Duration(milliseconds: 100));
          completer.complete();
          return Response.ok('ok');
        },
        'localhost',
        0,
      );

      final socket = await Socket.connect('localhost', server.port);
      socket.add(utf8.encode('GET / HTTP/1.1\r\nHost: localhost\r\n\r\n'));
      await socket.close(); // Close before response

      await completer.future;
    });
  });
}
