// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:bottom_shelf/bottom_shelf.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Serves [handler], sends one GET, returns the raw response bytes decoded
/// as Latin-1 (so arbitrary bytes survive).
Future<String> _rawResponse(Handler handler) async {
  final server = await RawShelfServer.serve(
    handler,
    'localhost',
    0,
    // Quiet the expected serialization errors.
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
  addTearDown(socket.destroy);
  // `Connection: close` so the stream ends after one response.
  socket.add(
    utf8.encode(
      'GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n',
    ),
  );
  return latin1.decodeStream(socket);
}

void main() {
  group('response header validation (anti response-splitting)', () {
    test('CRLF in a header value yields 500, not an injected header', () async {
      final response = await _rawResponse(
        (request) => Response.ok(
          'body',
          headers: {'x-evil': 'a\r\nx-injected: 1\r\n\r\nHTTP/1.1 200 OK'},
        ),
      );
      expect(response, startsWith('HTTP/1.1 500'));
      expect(response, isNot(contains('x-injected')));
    });

    test('bare LF in a header value yields 500', () async {
      final response = await _rawResponse(
        (request) =>
            Response.ok('body', headers: {'x-evil': 'a\nx-injected: 1'}),
      );
      expect(response, startsWith('HTTP/1.1 500'));
      expect(response, isNot(contains('x-injected')));
    });

    test('NUL in a header value yields 500', () async {
      final response = await _rawResponse(
        (request) => Response.ok('body', headers: {'x-evil': 'a\x00b'}),
      );
      expect(response, startsWith('HTTP/1.1 500'));
    });

    test('non-Latin-1 code unit in a header value yields 500', () async {
      final response = await _rawResponse(
        (request) => Response.ok('body', headers: {'x-evil': 'snow☃man'}),
      );
      expect(response, startsWith('HTTP/1.1 500'));
    });

    test('CRLF in a header name yields 500', () async {
      final response = await _rawResponse(
        (request) =>
            Response.ok('body', headers: {'x-evil\r\nx-injected': '1'}),
      );
      expect(response, startsWith('HTTP/1.1 500'));
      expect(response, isNot(contains('x-injected')));
    });

    test('space in a header name yields 500 (not a tchar)', () async {
      final response = await _rawResponse(
        (request) => Response.ok('body', headers: {'x evil': '1'}),
      );
      expect(response, startsWith('HTTP/1.1 500'));
    });

    test('Latin-1 header value passes through unmodified', () async {
      final response = await _rawResponse(
        (request) => Response.ok('body', headers: {'x-latin': 'café'}),
      );
      expect(response, startsWith('HTTP/1.1 200'));
      expect(response, contains('x-latin: café'));
    });

    test('multi-value headers are joined with a comma', () async {
      final response = await _rawResponse(
        (request) => Response.ok(
          'body',
          headers: {
            'x-multi': ['a', 'b'],
          },
        ),
      );
      expect(response, startsWith('HTTP/1.1 200'));
      expect(response, contains('x-multi: a, b'));
    });
  });
}
