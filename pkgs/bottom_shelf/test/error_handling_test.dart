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

  test('socket is destroyed on error during body streaming', () async {
    final server = await RawShelfServer.serve(
      (request) {
        final controller = StreamController<List<int>>();
        controller.add('hello'.codeUnits);
        // Schedule an error on the stream
        Future(() {
          controller.addError(StateError('error during streaming'));
          controller.close();
        });
        return Response.ok(controller.stream);
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

    // Socket should be destroyed on error, so doneCompleter should complete!
    await expectLater(doneCompleter.future, completes);

    final str = utf8.decode(responseBytes);
    expect(str, contains('hello'));
    // It should NOT contain the chunked end '0\r\n\r\n'!
    expect(str, isNot(contains('0\r\n\r\n')));
  });

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

  test(
    'client reset during response stream write does not crash server',
    () async {
      final server = await RawShelfServer.serve(
        (request) {
          if (request.url.path == 'second') {
            return Response.ok('ok');
          }
          final controller = StreamController<List<int>>();
          Timer.periodic(const Duration(milliseconds: 10), (timer) {
            if (controller.isClosed) {
              timer.cancel();
              return;
            }
            try {
              controller.add('chunk'.codeUnits);
            } catch (_) {
              timer.cancel();
            }
          });
          return Response.ok(controller.stream);
        },
        'localhost',
        0,
      );
      addTearDown(server.close);

      final socket = await Socket.connect('localhost', server.port);
      socket.write(
        'GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n',
      );
      await socket.flush();

      final completer = Completer<void>();
      socket.listen(
        (data) {
          if (!completer.isCompleted) {
            completer.complete();
            socket.destroy();
          }
        },
        onError: (_) {},
        onDone: () {},
      );

      await completer.future;

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final secondSocket = await Socket.connect('localhost', server.port);
      secondSocket.write(
        'GET /second HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n',
      );
      await secondSocket.flush();

      final response = await utf8.decodeStream(secondSocket);
      expect(response, contains('HTTP/1.1 200 OK'));
      expect(response, contains('ok'));
      await secondSocket.close();
    },
  );

  test('response Content-Length underflow and overflow mismatches close the '
      'connection', () async {
    final errors = <Object>[];
    final server = await RawShelfServer.serve(
      (request) {
        if (request.url.path == 'underflow') {
          return Response.ok(
            Stream.fromIterable(['short'.codeUnits]),
            headers: {'Content-Length': '10'},
          );
        }
        return Response.ok(
          Stream.fromIterable(['first-'.codeUnits, 'overflow-chunk'.codeUnits]),
          headers: {'Content-Length': '8'},
        );
      },
      'localhost',
      0,
      onConnectionError:
          (
            message,
            error,
            stackTrace, {
            required remoteAddress,
            required remotePort,
          }) {
            errors.add(error);
          },
    );
    addTearDown(server.close);

    // 1. Underflow on keep-alive connection closes the socket
    final s1 = await Socket.connect('localhost', server.port);
    addTearDown(s1.close);
    s1.write(
      'GET /underflow HTTP/1.1\r\n'
      'Host: localhost\r\n'
      'Connection: keep-alive\r\n\r\n',
    );
    final r1 = await utf8.decodeStream(s1);
    expect(r1, contains('short'));
    expect(r1, isNot(contains('HTTP/1.1 500')));

    // 2. Overflow on keep-alive connection aborts and closes the socket
    final s2 = await Socket.connect('localhost', server.port);
    addTearDown(s2.close);
    s2.write(
      'GET /overflow HTTP/1.1\r\n'
      'Host: localhost\r\n'
      'Connection: keep-alive\r\n\r\n',
    );
    final r2 = await utf8.decodeStream(s2);
    expect(r2, contains('first-'));
    expect(r2, isNot(contains('overflow-chunk')));
    expect(errors, hasLength(2));
    expect(errors.every((e) => e is StateError), isTrue);
  });

  test('unread response stream is cancelled when content-length: 0 or '
      'status is 204', () async {
    var cancelledZero = false;
    var cancelled204 = false;

    final server = await RawShelfServer.serve(
      (request) {
        if (request.url.path == 'zero') {
          final controller = StreamController<List<int>>(
            onCancel: () {
              cancelledZero = true;
            },
          );
          return Response.ok(
            controller.stream,
            headers: {'Content-Length': '0'},
          );
        }
        final controller = StreamController<List<int>>(
          onCancel: () {
            cancelled204 = true;
          },
        );
        return Response(204, body: controller.stream);
      },
      'localhost',
      0,
    );
    addTearDown(server.close);

    final s1 = await Socket.connect('localhost', server.port);
    addTearDown(s1.close);
    s1.write(
      'GET /zero HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n',
    );
    await utf8.decodeStream(s1);
    expect(cancelledZero, isTrue);

    final s2 = await Socket.connect('localhost', server.port);
    addTearDown(s2.close);
    s2.write(
      'GET /204 HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n',
    );
    await utf8.decodeStream(s2);
    expect(cancelled204, isTrue);
  });

  test('early handler response + malformed chunked request body race does not '
      'splice 400 into 200 response', () async {
    final responseGate = Completer<void>();
    final server = await RawShelfServer.serve(
      (request) {
        final controller = StreamController<List<int>>();
        controller.add('part1-'.codeUnits);
        responseGate.future.then((_) {
          if (!controller.isClosed) {
            controller.add('part2'.codeUnits);
            controller.close();
          }
        });
        return Response.ok(
          controller.stream,
          headers: {'Content-Length': '11'},
        );
      },
      'localhost',
      0,
      onConnectionError:
          (
            message,
            error,
            stackTrace, {
            required remoteAddress,
            required remotePort,
          }) {},
    );
    addTearDown(server.close);

    final socket = await Socket.connect('localhost', server.port);
    addTearDown(socket.close);

    // Send headers for chunked POST; handler starts writing 200 immediately
    socket.add(
      utf8.encode(
        'POST / HTTP/1.1\r\n'
        'Host: localhost\r\n'
        'Transfer-Encoding: chunked\r\n\r\n',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    // Now send malformed chunk size while response is already writing
    socket.add(utf8.encode('ZZZ\r\n'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    responseGate.complete();

    final response = await utf8.decodeStream(socket);
    expect(response, startsWith('HTTP/1.1 200 OK'));
    expect(response, isNot(contains('400 Bad Request')));
  });

  test('BadRequestException.toString formats message and innerException', () {
    const simple = BadRequestException('invalid header');
    expect(simple.toString(), 'BadRequestException: invalid header');

    const withInner = BadRequestException(
      'bad url',
      innerException: FormatException('bad scheme'),
    );
    expect(
      withInner.toString(),
      'BadRequestException: bad url\n'
      'Inner exception: FormatException: bad scheme',
    );
  });
}
