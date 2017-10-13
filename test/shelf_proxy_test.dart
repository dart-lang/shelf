// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scheduled_test/scheduled_test.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_proxy/shelf_proxy.dart';

/// The URI of the server the current proxy server is proxying to.
Uri targetUri;

/// The URI of the current proxy server.
Uri proxyUri;

void main() {
  group("forwarding", () {
    test("forwards request method", () {
      createProxy((request) {
        expect(request.method, equals('DELETE'));
        return new shelf.Response.ok(':)');
      });

      schedule(() => http.delete(proxyUri));
    });

    test("forwards request headers", () {
      createProxy((request) {
        expect(request.headers, containsPair('foo', 'bar'));
        expect(request.headers, containsPair('accept', '*/*'));
        return new shelf.Response.ok(':)');
      });

      get(headers: {'foo': 'bar', 'accept': '*/*'});
    });

    test("forwards request body", () {
      createProxy((request) {
        expect(request.readAsString(), completion(equals('hello, server')));
        return new shelf.Response.ok(':)');
      });

      schedule(() => http.post(proxyUri, body: 'hello, server'));
    });

    test("forwards response status", () {
      createProxy((request) {
        return new shelf.Response(567);
      });

      expect(
          get().then((response) {
            expect(response.statusCode, equals(567));
          }),
          completes);
    });

    test("forwards response headers", () {
      createProxy((request) {
        return new shelf.Response.ok(':)',
            headers: {'foo': 'bar', 'accept': '*/*'});
      });

      expect(
          get().then((response) {
            expect(response.headers, containsPair('foo', 'bar'));
            expect(response.headers, containsPair('accept', '*/*'));
          }),
          completes);
    });

    test("forwards response body", () {
      createProxy((request) {
        return new shelf.Response.ok('hello, client');
      });

      expect(schedule(() => http.read(proxyUri)),
          completion(equals('hello, client')));
    });

    test("adjusts the Host header for the target server", () {
      createProxy((request) {
        expect(request.headers, containsPair('host', targetUri.authority));
        return new shelf.Response.ok(':)');
      });

      get();
    });
  });

  group("via", () {
    test("adds a Via header to the request", () {
      createProxy((request) {
        expect(request.headers, containsPair('via', '1.1 shelf_proxy'));
        return new shelf.Response.ok(':)');
      });

      get();
    });

    test("adds to a request's existing Via header", () {
      createProxy((request) {
        expect(request.headers,
            containsPair('via', '1.0 something, 1.1 shelf_proxy'));
        return new shelf.Response.ok(':)');
      });

      get(headers: {'via': '1.0 something'});
    });

    test("adds a Via header to the response", () {
      createProxy((request) => new shelf.Response.ok(':)'));

      expect(
          get().then((response) {
            expect(response.headers, containsPair('via', '1.1 shelf_proxy'));
          }),
          completes);
    });

    test("adds to a response's existing Via header", () {
      createProxy((request) {
        return new shelf.Response.ok(':)', headers: {'via': '1.0 something'});
      });

      expect(
          get().then((response) {
            expect(response.headers,
                containsPair('via', '1.0 something, 1.1 shelf_proxy'));
          }),
          completes);
    });

    test("adds to a response's existing Via header", () {
      createProxy((request) {
        return new shelf.Response.ok(':)', headers: {'via': '1.0 something'});
      });

      expect(
          get().then((response) {
            expect(response.headers,
                containsPair('via', '1.0 something, 1.1 shelf_proxy'));
          }),
          completes);
    });
  });

  group("redirects", () {
    test("doesn't modify a Location for a foreign server", () {
      createProxy((request) {
        return new shelf.Response.found('http://dartlang.org');
      });

      expect(
          get().then((response) {
            expect(response.headers,
                containsPair('location', 'http://dartlang.org'));
          }),
          completes);
    });

    test("relativizes a reachable root-relative Location", () {
      createProxy((request) {
        return new shelf.Response.found('/foo/bar');
      }, targetPath: '/foo');

      expect(
          get().then((response) {
            expect(response.headers, containsPair('location', '/bar'));
          }),
          completes);
    });

    test("absolutizes an unreachable root-relative Location", () {
      createProxy((request) {
        return new shelf.Response.found('/baz');
      }, targetPath: '/foo');

      expect(
          get().then((response) {
            expect(response.headers,
                containsPair('location', targetUri.resolve('/baz').toString()));
          }),
          completes);
    });
  });

  test("removes a transfer-encoding header", () async {
    var handler = mockHandler((request) {
      return new http.Response('', 200,
          headers: {'transfer-encoding': 'chunked'});
    });

    var response =
        await handler(new shelf.Request('GET', Uri.parse('http://localhost/')));

    expect(response.headers, isNot(contains("transfer-encoding")));
  });

  test("removes content-length and content-encoding for a gzipped response",
      () async {
    var handler = mockHandler((request) {
      return new http.Response('', 200,
          headers: {'content-encoding': 'gzip', 'content-length': '1234'});
    });

    var response =
        await handler(new shelf.Request('GET', Uri.parse('http://localhost/')));

    expect(response.headers, isNot(contains("content-encoding")));
    expect(response.headers, isNot(contains("content-length")));
    expect(response.headers,
        containsPair('warning', '214 shelf_proxy "GZIP decoded"'));
  });
}

/// Creates a proxy server proxying to a server running [handler].
///
/// [targetPath] is the root-relative path on the target server to proxy to. It
/// defaults to `/`.
void createProxy(shelf.Handler handler, {String targetPath}) {
  handler = expectAsync1(handler, reason: 'target server handler');
  schedule(() async {
    var targetServer = await shelf_io.serve(handler, 'localhost', 0);
    targetUri = Uri.parse('http://localhost:${targetServer.port}');
    if (targetPath != null) targetUri = targetUri.resolve(targetPath);
    var proxyServerHandler =
        expectAsync1(proxyHandler(targetUri), reason: 'proxy server handler');

    var proxyServer = await shelf_io.serve(proxyServerHandler, 'localhost', 0);
    proxyUri = Uri.parse('http://localhost:${proxyServer.port}');

    currentSchedule.onComplete.schedule(() {
      proxyServer.close(force: true);
      targetServer.close(force: true);
    }, 'tear down servers');
  }, 'spin up servers');
}

/// Creates a [shelf.Handler] that's backed by a [MockClient] running
/// [callback].
shelf.Handler mockHandler(
    FutureOr<http.Response> callback(http.Request request)) {
  var client = new MockClient((request) async => await callback(request));
  return proxyHandler('http://dartlang.org', client: client);
}

/// Schedules a GET request with [headers] to the proxy server.
Future<http.Response> get({Map<String, String> headers}) {
  return schedule(() {
    var uri = proxyUri;
    var request = new http.Request('GET', uri);
    if (headers != null) request.headers.addAll(headers);
    request.followRedirects = false;
    return request.send().then(http.Response.fromStream);
  }, 'GET proxy server');
}
