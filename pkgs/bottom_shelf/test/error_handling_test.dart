// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bottom_shelf/bottom_shelf.dart';
import 'package:bottom_shelf/src/exceptions.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  test(
    'default behavior (null) destroys socket on async error after response',
    () async {
      final errorCompleter = Completer<void>();
      final server = await RawShelfServer.serve(
        (request) {
          Future(() {
            errorCompleter.complete();
            throw StateError('async error');
          });
          return Response.ok('hello');
        },
        'localhost',
        0,
      );
      addTearDown(server.close);

      final socket = await Socket.connect('localhost', server.port);
      socket.write(
        'GET / HTTP/1.1\r\nHost: localhost\r\nConnection: keep-alive\r\n\r\n',
      );

      final responseBytes = <int>[];
      final doneCompleter = Completer<void>();
      socket.listen(responseBytes.addAll, onDone: doneCompleter.complete);

      await errorCompleter.future; // Wait for async error

      // Socket should be destroyed, so doneCompleter should complete!
      await expectLater(doneCompleter.future, completes);

      final str = utf8.decode(responseBytes);
      expect(str, contains('hello'));
    },
  );

  test(
    'ErrorAction.ignore keeps socket alive on async error after response',
    () async {
      final errorCompleter = Completer<void>();
      final server = await RawShelfServer.serve(
        (request) {
          if (request.url.path == 'second') {
            return Response.ok('second');
          }
          Future(() {
            errorCompleter.complete();
            throw StateError('async error');
          });
          return Response.ok('hello');
        },
        'localhost',
        0,
        onAsyncError: (e, st) => ErrorAction.ignore,
      );
      addTearDown(server.close);

      final socket = await Socket.connect('localhost', server.port);
      socket.write(
        'GET / HTTP/1.1\r\nHost: localhost\r\nConnection: keep-alive\r\n\r\n',
      );

      final responseBytes = <int>[];
      final doneCompleter = Completer<void>();
      socket.listen(responseBytes.addAll, onDone: doneCompleter.complete);

      await errorCompleter.future; // Wait for async error

      // Socket should NOT be destroyed.
      // We should be able to send another request.
      socket.write(
        'GET /second HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n',
      );

      await expectLater(doneCompleter.future, completes);

      final str = utf8.decode(responseBytes);
      expect(str, contains('hello'));
      expect(str, contains('second'));
    },
  );

  test(
    'ErrorAction.destroy destroys socket on async error after response',
    () async {
      final errorCompleter = Completer<void>();
      final server = await RawShelfServer.serve(
        (request) {
          Future(() {
            errorCompleter.complete();
            throw StateError('async error');
          });
          return Response.ok('hello');
        },
        'localhost',
        0,
        onAsyncError: (e, st) => ErrorAction.destroy,
      );
      addTearDown(server.close);

      final socket = await Socket.connect('localhost', server.port);
      socket.write(
        'GET / HTTP/1.1\r\nHost: localhost\r\nConnection: keep-alive\r\n\r\n',
      );

      final responseBytes = <int>[];
      final doneCompleter = Completer<void>();
      socket.listen(responseBytes.addAll, onDone: doneCompleter.complete);

      await errorCompleter.future; // Wait for async error

      await expectLater(doneCompleter.future, completes);

      final str = utf8.decode(responseBytes);
      expect(str, contains('hello'));
    },
  );

  test('ErrorAction.crash causes process to exit', () async {
    final process = await Process.start(Platform.executable, [
      'test/crash_server.dart',
      'crash',
    ]);

    final lines = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    final portLine = await lines.first;
    final port = int.parse(portLine.split(' ').last);

    final socket = await Socket.connect('localhost', port);
    socket.write(
      'GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n',
    );
    await socket.toList();

    final exitCode = await process.exitCode;
    expect(exitCode, isNot(0));
  });

  test('callback throws causes process to exit', () async {
    final process = await Process.start(Platform.executable, [
      'test/crash_server.dart',
      'throw',
    ]);

    final lines = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    final portLine = await lines.first;
    final port = int.parse(portLine.split(' ').last);

    final socket = await Socket.connect('localhost', port);
    socket.write(
      'GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n',
    );
    await socket.toList();

    final exitCode = await process.exitCode;
    expect(exitCode, isNot(0));
  });
}
