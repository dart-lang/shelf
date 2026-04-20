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

  group('Connections', () {
    test('Hijacking (detach socket)', () async {
      final completer = Completer<void>();
      server = await RawShelfServer.serve(
        (request) {
          request.hijack((channel) {
            channel.sink.add(
              utf8.encode(
                'HTTP/1.1 101 Switching Protocols\r\n\r\nCustom Data',
              ),
            );
            channel.sink.close();
            completer.complete();
          });
        },
        'localhost',
        0,
      );

      final socket = await Socket.connect('localhost', server.port);
      socket.add(utf8.encode('GET / HTTP/1.1\r\nHost: localhost\r\n\r\n'));

      final response = await utf8.decodeStream(socket);
      expect(response, contains('101 Switching Protocols'));
      expect(response, contains('Custom Data'));
      await completer.future;
    });

    test('Keep-alive behavior', () async {
      var count = 0;
      server = await RawShelfServer.serve(
        (request) {
          count++;
          return Response.ok('$count');
        },
        'localhost',
        0,
      );

      final socket = await Socket.connect('localhost', server.port);
      final completer = Completer<String>();
      final chunks = <String>[];

      socket.listen(
        (data) {
          chunks.add(utf8.decode(data));
          final full = chunks.join();
          if (full.contains('2')) {
            if (!completer.isCompleted) completer.complete(full);
          }
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete(chunks.join());
        },
      );

      // Request 1
      socket.add(utf8.encode('GET / HTTP/1.1\r\nHost: localhost\r\n\r\n'));

      // Delay to ensure it's not all one chunk if we want to test separation,
      // but the server handles both.
      await Future.delayed(Duration(milliseconds: 50));

      // Request 2
      socket.add(
        utf8.encode(
          'GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n',
        ),
      );

      final response = await completer.future;
      expect(response, contains('1'));
      expect(response, contains('2'));
    });
  });
}
