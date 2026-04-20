// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

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
      await socket.drain();
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
  });
}
