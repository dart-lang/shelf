// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:shelf_test_handler/shelf_test_handler.dart';

void main() {
  group("invokes the handler(s)", () {
    ShelfTestHandler handler;
    setUp(() {
      handler = new ShelfTestHandler();
    });

    test("with the expected method and path", () async {
      handler.expect("GET", "/", expectAsync1((_) => new Response.ok("")));
      var response = await handler(_get("/"));
      expect(response.statusCode, equals(200));
    });

    test("in queue order", () async {
      handler.expect("GET", "/", expectAsync1((_) => new Response.ok("1")));
      handler.expect("GET", "/", expectAsync1((_) => new Response.ok("2")));
      handler.expect("GET", "/", expectAsync1((_) => new Response.ok("3")));

      expect(await (await handler(_get("/"))).readAsString(), equals("1"));
      expect(await (await handler(_get("/"))).readAsString(), equals("2"));
      expect(await (await handler(_get("/"))).readAsString(), equals("3"));
    });

    test("interleaved with requests", () async {
      handler.expect("GET", "/", expectAsync1((_) => new Response.ok("1")));
      expect(await (await handler(_get("/"))).readAsString(), equals("1"));

      handler.expect("GET", "/", expectAsync1((_) => new Response.ok("2")));
      expect(await (await handler(_get("/"))).readAsString(), equals("2"));

      handler.expect("GET", "/", expectAsync1((_) => new Response.ok("3")));
      expect(await (await handler(_get("/"))).readAsString(), equals("3"));
    });

    test("for expectAnything()", () async {
      handler.expectAnything(expectAsync1((request) {
        expect(request.method, equals("GET"));
        expect(request.url.path, equals("foo/bar"));
        return new Response.ok("");
      }));

      var response = await handler(_get("/foo/bar"));
      expect(response.statusCode, equals(200));
    });
  });

  group("throws a TestFailure", () {
    test("without any expectations", () {
      _expectZoneFailure(() async {
        var handler = new ShelfTestHandler();
        await handler(_get("/"));
      });
    });

    test("when all expectations are exhausted", () {
      _expectZoneFailure(() async {
        var handler = new ShelfTestHandler();
        handler.expect("GET", "/", expectAsync1((_) => new Response.ok("")));
        await handler(_get("/"));
        await handler(_get("/"));
      });
    });

    test("when the method doesn't match the expectation", () {
      _expectZoneFailure(() async {
        var handler = new ShelfTestHandler();
        handler.expect("POST", "/", expectAsync1((_) {}, count: 0));
        await handler(_get("/"));
      });
    });

    test("when the path doesn't match the expectation", () {
      _expectZoneFailure(() async {
        var handler = new ShelfTestHandler();
        handler.expect("GET", "/foo", expectAsync1((_) {}, count: 0));
        await handler(_get("/"));
      });
    });

    test("if the handler returns null", () {
      _expectZoneFailure(() async {
        var handler = new ShelfTestHandler();
        handler.expect("GET", "/", (_) => null);
        await handler(_get("/"));
      });
    });
  });

  test("doesn't swallow handler errors", () {
    runZoned(() async {
      var handler = new ShelfTestHandler();
      handler.expect("GET", "/", (_) => throw "oh heck");
      await handler(_get("/"));
    }, onError: expectAsync1((error) {
      expect(error, equals("oh heck"));
    }));
  });
}

void _expectZoneFailure(Future callback()) {
  runZoned(callback, onError: expectAsync1((error) {
    expect(error, new TypeMatcher<TestFailure>());
  }));
}

Request _get(String path) =>
    new Request("GET", Uri.parse("http://localhost:80$path"));
