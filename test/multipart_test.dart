// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:mime/mime.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'test_util.dart';

void main() {
  group('isMultipart returns', () {
    test('false for requests without a content-type header', () async {
      Response handler(Request r) => Response.ok(r.isMultipart.toString());
      final response = await makeSimpleRequest(handler);
      expect(response.readAsString(), completion('false'));
    });

    test('false for Content-Type: multipart without boundary', () {
      expect(
        Request('GET', localhostUri,
            headers: {'Content-Type': 'multipart/mixed'}).isMultipart,
        isFalse,
      );
    });

    test('true for multipart headers', () {
      expect(
        Request('GET', localhostUri, headers: {
          'Content-Type': 'multipart/mixed; boundary=gc0p4Jq0M2Yt08j34c0p'
        }).isMultipart,
        isTrue,
      );
    });
  });

  test('can access part headers without case sensitivity', () async {
    Future<Response> handler(Request request) async {
      final part = await request.parts.first;
      return Response.ok(part.headers['foo'].toString());
    }

    final response = await handler(Request(
      'POST',
      localhostUri,
      body: '\r\n--end\r\n'
          'FOO: header value\r\n'
          '\r\n'
          'content\r\n'
          '--end--',
      headers: {
        'Content-Type': 'multipart/mixed; boundary=end',
      },
    ));

    expect(response.readAsString(), completion('header value'));
  });

  test('can access multipart bodies', () async {
    Future<Response> handler(Request request) async {
      final result = StringBuffer();
      await for (final part in request.parts) {
        await utf8.decoder.bind(part).forEach(result.write);
      }

      return Response.ok(result.toString());
    }

    final response = await handler(Request(
      'POST',
      localhostUri,
      body: '\r\n--end\r\n'
          '\r\n'
          'first part, no line break\r\n'
          '--end\r\n'
          '\r\n'
          'second part, with line break\n'
          '\r\n'
          '--end--\r\n',
      headers: {
        'Content-Type': 'multipart/mixed; boundary=end',
      },
    ));

    expect(
      response.readAsString(),
      completion('first part, no line breaksecond part, with line break\n'),
    );
  });

  test('throws when calling .parts on a non-multipart request', () {
    Response handler(Request request) => Response.ok(request.parts.toString());

    expect(makeSimpleRequest(handler), throwsStateError);
  });

  test('throws when reading an ill-formed multipart body', () {
    Future<Response> handler(Request request) async {
      await for (final _ in request.parts) {}

      return Response.ok('ok');
    }

    final request = Request(
      'POST',
      localhostUri,
      body: '\r\n--end\r\n'
          '\r\n'
          'missing -- from end\r\n'
          '--end\r\n',
      headers: {
        'Content-Type': 'multipart/mixed; boundary=end',
      },
    );

    expect(handler(request), throwsA(isA<MimeMultipartException>()));
  });
}
