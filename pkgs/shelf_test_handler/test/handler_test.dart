// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:shelf/shelf.dart';
import 'package:shelf_test_handler/shelf_test_handler.dart';
import 'package:test/test.dart';

void main() {
  group('invokes the handler(s)', () {
    late ShelfTestHandler handler;
    setUp(() {
      handler = ShelfTestHandler();
    });

    test('with the expected method and path', () async {
      handler.expect('GET', '/', expectAsync1((_) => Response.ok('')));
      var response = await handler(_get('/'));
      expect(response.statusCode, equals(200));
    });

    test('in queue order', () async {
      handler.expect('GET', '/', expectAsync1((_) => Response.ok('1')));
      handler.expect('GET', '/', expectAsync1((_) => Response.ok('2')));
      handler.expect('GET', '/', expectAsync1((_) => Response.ok('3')));

      expect(await (await handler(_get('/'))).readAsString(), equals('1'));
      expect(await (await handler(_get('/'))).readAsString(), equals('2'));
      expect(await (await handler(_get('/'))).readAsString(), equals('3'));
    });

    test('interleaved with requests', () async {
      handler.expect('GET', '/', expectAsync1((_) => Response.ok('1')));
      expect(await (await handler(_get('/'))).readAsString(), equals('1'));

      handler.expect('GET', '/', expectAsync1((_) => Response.ok('2')));
      expect(await (await handler(_get('/'))).readAsString(), equals('2'));

      handler.expect('GET', '/', expectAsync1((_) => Response.ok('3')));
      expect(await (await handler(_get('/'))).readAsString(), equals('3'));
    });

    test('for expectAnything()', () async {
      handler.expectAnything(expectAsync1((request) {
        expect(request.method, equals('GET'));
        expect(request.url.path, equals('foo/bar'));
        return Response.ok('');
      }));

      var response = await handler(_get('/foo/bar'));
      expect(response.statusCode, equals(200));
    });
  });

  group('throws a TestFailure', () {
    test('without any expectations', () {
      _expectZoneFailure(() async {
        var handler = ShelfTestHandler();
        await handler(_get('/'));
      });
    });

    test('when all expectations are exhausted', () {
      _expectZoneFailure(() async {
        var handler = ShelfTestHandler();
        handler.expect('GET', '/', expectAsync1((_) => Response.ok('')));
        await handler(_get('/'));
        await handler(_get('/'));
      });
    });

    test("when the method doesn't match the expectation", () {
      _expectZoneFailure(() async {
        var handler = ShelfTestHandler();
        handler.expect(
            'POST',
            '/',
            expectAsync1(
              (_) {
                fail('should never get here');
              },
              count: 0,
            ));
        await handler(_get('/'));
      });
    });

    test("when the path doesn't match the expectation", () {
      _expectZoneFailure(() async {
        var handler = ShelfTestHandler();
        handler.expect(
            'GET',
            '/foo',
            expectAsync1((_) {
              fail('should never get here');
            }, count: 0));
        await handler(_get('/'));
      });
    });
  });

  test("doesn't swallow handler errors", () {
    runZonedGuarded(() async {
      var handler = ShelfTestHandler();
      handler.expect('GET', '/', (_) => throw StateError('oh heck'));
      await handler(_get('/'));
    }, expectAsync2((error, stack) {
      expect(error,
          isA<StateError>().having((p0) => p0.message, 'message', 'oh heck'));
    }));
  });
}

void _expectZoneFailure(Future<void> Function() callback) {
  runZonedGuarded(callback, expectAsync2((error, stack) {
    expect(error, isA<TestFailure>());
  }));
}

Request _get(String path) =>
    Request('GET', Uri.parse('http://localhost:80$path'));
