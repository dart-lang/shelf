// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart' hide Request;
import 'package:test/test.dart';

import 'test_util.dart';

void main() {
  group("supports a String body", () {
    test("readAsString", () {
      var response = new Response.ok("hello, world");
      expect(response.readAsString(), completion(equals("hello, world")));
    });

    test("read", () {
      var helloWorldBytes = new List.from(helloBytes)..addAll(worldBytes);

      var response = new Response.ok("hello, world");
      expect(response.read().toList(), completion(equals([helloWorldBytes])));
    });
  });

  group("new Response.internalServerError without a body", () {
    test('sets the body to "Internal Server Error"', () {
      var response = new Response.internalServerError();
      expect(
          response.readAsString(), completion(equals("Internal Server Error")));
    });

    test('sets the content-type header to text/plain', () {
      var response = new Response.internalServerError();
      expect(response.headers, containsPair('content-type', 'text/plain'));
    });

    test('preserves content-type parameters', () {
      var response = new Response.internalServerError(headers: {
        'content-type': 'application/octet-stream; param=whatever'
      });
      expect(response.headers,
          containsPair('content-type', 'text/plain; param=whatever'));
    });
  });

  group("Response redirect", () {
    test("sets the location header for a String", () {
      var response = new Response.found('/foo');
      expect(response.headers, containsPair('location', '/foo'));
    });

    test("sets the location header for a Uri", () {
      var response = new Response.found(new Uri(path: '/foo'));
      expect(response.headers, containsPair('location', '/foo'));
    });
  });

  group("expires", () {
    test("is null without an Expires header", () {
      expect(new Response.ok("okay!").expires, isNull);
    });

    test("comes from the Expires header", () {
      expect(
          new Response.ok("okay!",
              headers: {'expires': 'Sun, 06 Nov 1994 08:49:37 GMT'}).expires,
          equals(DateTime.parse("1994-11-06 08:49:37z")));
    });
  });

  group("lastModified", () {
    test("is null without a Last-Modified header", () {
      expect(new Response.ok("okay!").lastModified, isNull);
    });

    test("comes from the Last-Modified header", () {
      expect(
          new Response.ok("okay!",
                  headers: {'last-modified': 'Sun, 06 Nov 1994 08:49:37 GMT'})
              .lastModified,
          equals(DateTime.parse("1994-11-06 08:49:37z")));
    });
  });

  group('change', () {
    test('with no arguments returns instance with equal values', () {
      var controller = new StreamController();

      var request = new Response(345,
          body: 'hèllo, world',
          encoding: LATIN1,
          headers: {'header1': 'header value 1'},
          context: {'context1': 'context value 1'});

      var copy = request.change();

      expect(copy.statusCode, request.statusCode);
      expect(copy.readAsString(), completion('hèllo, world'));
      expect(copy.headers, same(request.headers));
      expect(copy.encoding, request.encoding);
      expect(copy.context, same(request.context));

      controller.add(helloBytes);
      return new Future(() {
        controller
          ..add(worldBytes)
          ..close();
      });
    });

    test("allows the original response to be read", () {
      var response = new Response.ok(null);
      var changed = response.change();

      expect(response.read().toList(), completion(isEmpty));
      expect(changed.read, throwsStateError);
    });

    test("allows the changed response to be read", () {
      var response = new Response.ok(null);
      var changed = response.change();

      expect(changed.read().toList(), completion(isEmpty));
      expect(response.read, throwsStateError);
    });

    test("allows another changed response to be read", () {
      var response = new Response.ok(null);
      var changed1 = response.change();
      var changed2 = response.change();

      expect(changed2.read().toList(), completion(isEmpty));
      expect(changed1.read, throwsStateError);
      expect(response.read, throwsStateError);
    });
  });
}
