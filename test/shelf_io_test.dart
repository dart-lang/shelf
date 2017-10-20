// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as parser;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

import 'ssl_certs.dart';
import 'test_util.dart';

void main() {
  tearDown(() async {
    if (_server != null) {
      await _server.close(force: true);
      _server = null;
    }
  });

  test('sync handler returns a value to the client', () async {
    await _scheduleServer(syncHandler);

    var response = await _get();
    expect(response.statusCode, HttpStatus.OK);
    expect(response.body, 'Hello from /');
  });

  test('async handler returns a value to the client', () async {
    await _scheduleServer(asyncHandler);

    var response = await _get();
    expect(response.statusCode, HttpStatus.OK);
    expect(response.body, 'Hello from /');
  });

  test('sync null response leads to a 500', () async {
    await _scheduleServer((request) => null);

    var response = await _get();
    expect(response.statusCode, HttpStatus.INTERNAL_SERVER_ERROR);
    expect(response.body, 'Internal Server Error');
  });

  test('async null response leads to a 500', () async {
    await _scheduleServer((request) => new Future.value(null));

    var response = await _get();
    expect(response.statusCode, HttpStatus.INTERNAL_SERVER_ERROR);
    expect(response.body, 'Internal Server Error');
  });

  test('thrown error leads to a 500', () async {
    await _scheduleServer((request) {
      throw new UnsupportedError('test');
    });

    var response = await _get();
    expect(response.statusCode, HttpStatus.INTERNAL_SERVER_ERROR);
    expect(response.body, 'Internal Server Error');
  });

  test('async error leads to a 500', () async {
    await _scheduleServer((request) {
      return new Future.error('test');
    });

    var response = await _get();
    expect(response.statusCode, HttpStatus.INTERNAL_SERVER_ERROR);
    expect(response.body, 'Internal Server Error');
  });

  test('Request is populated correctly', () async {
    var path = '/foo/bar?qs=value';

    await _scheduleServer((request) {
      expect(request.contentLength, 0);
      expect(request.method, 'GET');

      var expectedUrl = 'http://localhost:$_serverPort$path';
      expect(request.requestedUri, Uri.parse(expectedUrl));

      expect(request.url.path, 'foo/bar');
      expect(request.url.pathSegments, ['foo', 'bar']);
      expect(request.protocolVersion, '1.1');
      expect(request.url.query, 'qs=value');
      expect(request.handlerPath, '/');

      return syncHandler(request);
    });

    var response = await http.get('http://localhost:$_serverPort$path');
    expect(response.statusCode, HttpStatus.OK);
    expect(response.body, 'Hello from /foo/bar');
  });

  test('chunked requests are un-chunked', () async {
    await _scheduleServer(expectAsync1((request) {
      expect(request.contentLength, isNull);
      expect(request.method, 'POST');
      expect(request.headers, isNot(contains(HttpHeaders.TRANSFER_ENCODING)));
      expect(
          request.read().toList(),
          completion(equals([
            [1, 2, 3, 4]
          ])));
      return new Response.ok(null);
    }));

    var request = new http.StreamedRequest(
        'POST', Uri.parse('http://localhost:$_serverPort'));
    request.sink.add([1, 2, 3, 4]);
    request.sink.close();

    var response = await request.send();
    expect(response.statusCode, HttpStatus.OK);
  });

  test('custom response headers are received by the client', () async {
    await _scheduleServer((request) {
      return new Response.ok('Hello from /',
          headers: {'test-header': 'test-value', 'test-list': 'a, b, c'});
    });

    var response = await _get();
    expect(response.statusCode, HttpStatus.OK);
    expect(response.headers['test-header'], 'test-value');
    expect(response.body, 'Hello from /');
  });

  test('custom status code is received by the client', () async {
    await _scheduleServer((request) {
      return new Response(299, body: 'Hello from /');
    });

    var response = await _get();
    expect(response.statusCode, 299);
    expect(response.body, 'Hello from /');
  });

  test('custom request headers are received by the handler', () async {
    await _scheduleServer((request) {
      expect(request.headers, containsPair('custom-header', 'client value'));

      // dart:io HttpServer splits multi-value headers into an array
      // validate that they are combined correctly
      expect(request.headers, containsPair('multi-header', 'foo,bar,baz'));
      return syncHandler(request);
    });

    var headers = {
      'custom-header': 'client value',
      'multi-header': 'foo,bar,baz'
    };

    var response = await _get(headers: headers);
    expect(response.statusCode, HttpStatus.OK);
    expect(response.body, 'Hello from /');
  });

  test('post with empty content', () async {
    await _scheduleServer((request) async {
      expect(request.mimeType, isNull);
      expect(request.encoding, isNull);
      expect(request.method, 'POST');
      expect(request.contentLength, 0);

      var body = await request.readAsString();
      expect(body, '');
      return syncHandler(request);
    });

    var response = await _post();
    expect(response.statusCode, HttpStatus.OK);
    expect(response.stream.bytesToString(), completion('Hello from /'));
  });

  test('post with request content', () async {
    await _scheduleServer((request) async {
      expect(request.mimeType, 'text/plain');
      expect(request.encoding, UTF8);
      expect(request.method, 'POST');
      expect(request.contentLength, 9);

      var body = await request.readAsString();
      expect(body, 'test body');
      return syncHandler(request);
    });

    var response = await _post(body: 'test body');
    expect(response.statusCode, HttpStatus.OK);
    expect(response.stream.bytesToString(), completion('Hello from /'));
  });

  test('supports request hijacking', () async {
    await _scheduleServer((request) {
      expect(request.method, 'POST');

      request.hijack(expectAsync1((channel) {
        expect(channel.stream.first, completion(equals("Hello".codeUnits)));

        channel.sink.add(("HTTP/1.1 404 Not Found\r\n"
                "Date: Mon, 23 May 2005 22:38:34 GMT\r\n"
                "Content-Length: 13\r\n"
                "\r\n"
                "Hello, world!")
            .codeUnits);
        channel.sink.close();
      }));
    });

    var response = await _post(body: "Hello");
    expect(response.statusCode, HttpStatus.NOT_FOUND);
    expect(response.headers["date"], "Mon, 23 May 2005 22:38:34 GMT");
    expect(
        response.stream.bytesToString(), completion(equals("Hello, world!")));
  });

  test('reports an error if a HijackException is thrown without hijacking',
      () async {
    await _scheduleServer((request) => throw const HijackException());

    var response = await _get();
    expect(response.statusCode, HttpStatus.INTERNAL_SERVER_ERROR);
  });

  test('passes asynchronous exceptions to the parent error zone', () async {
    await runZoned(() async {
      var server = await shelf_io.serve((request) {
        new Future(() => throw 'oh no');
        return syncHandler(request);
      }, 'localhost', 0);

      var response = await http.get('http://localhost:${server.port}');
      expect(response.statusCode, HttpStatus.OK);
      expect(response.body, 'Hello from /');
      await server.close();
    }, onError: expectAsync1((error) {
      expect(error, equals('oh no'));
    }));
  });

  test("doesn't pass asynchronous exceptions to the root error zone", () async {
    var response = await Zone.ROOT.run(() async {
      var server = await shelf_io.serve((request) {
        new Future(() => throw 'oh no');
        return syncHandler(request);
      }, 'localhost', 0);

      try {
        return await http.get('http://localhost:${server.port}');
      } finally {
        await server.close();
      }
    });

    expect(response.statusCode, HttpStatus.OK);
    expect(response.body, 'Hello from /');
  });

  test('a bad HTTP request results in a 500 response', () async {
    await _scheduleServer(syncHandler);

    var socket = await Socket.connect('localhost', _serverPort);

    try {
      socket.write('GET / HTTP/1.1\r\n');
      socket.write('Host: ^^super bad !@#host\r\n');
      socket.write('\r\n');
    } finally {
      await socket.close();
    }

    expect(
        await UTF8.decodeStream(socket), contains('500 Internal Server Error'));
  });

  group('date header', () {
    test('is sent by default', () async {
      await _scheduleServer(syncHandler);

      // Update beforeRequest to be one second earlier. HTTP dates only have
      // second-level granularity and the request will likely take less than a
      // second.
      var beforeRequest = new DateTime.now().subtract(new Duration(seconds: 1));

      var response = await _get();
      expect(response.headers, contains('date'));
      var responseDate = parser.parseHttpDate(response.headers['date']);

      expect(responseDate.isAfter(beforeRequest), isTrue);
      expect(responseDate.isBefore(new DateTime.now()), isTrue);
    });

    test('defers to header in response', () async {
      var date = new DateTime.utc(1981, 6, 5);
      await _scheduleServer((request) {
        return new Response.ok('test',
            headers: {HttpHeaders.DATE: parser.formatHttpDate(date)});
      });

      var response = await _get();
      expect(response.headers, contains('date'));
      var responseDate = parser.parseHttpDate(response.headers['date']);
      expect(responseDate, date);
    });
  });

  group('server header', () {
    test('defaults to "dart:io with Shelf"', () async {
      await _scheduleServer(syncHandler);

      var response = await _get();
      expect(response.headers,
          containsPair(HttpHeaders.SERVER, 'dart:io with Shelf'));
    });

    test('defers to header in response', () async {
      await _scheduleServer((request) {
        return new Response.ok('test',
            headers: {HttpHeaders.SERVER: 'myServer'});
      });

      var response = await _get();
      expect(response.headers, containsPair(HttpHeaders.SERVER, 'myServer'));
    });
  });

  group('chunked coding', () {
    group('is added when the transfer-encoding header is', () {
      test('unset', () async {
        await _scheduleServer((request) {
          return new Response.ok(new Stream.fromIterable([
            [1, 2, 3, 4]
          ]));
        });

        var response = await _get();
        expect(response.headers,
            containsPair(HttpHeaders.TRANSFER_ENCODING, 'chunked'));
        expect(response.bodyBytes, equals([1, 2, 3, 4]));
      });

      test('"identity"', () async {
        await _scheduleServer((request) {
          return new Response.ok(
              new Stream.fromIterable([
                [1, 2, 3, 4]
              ]),
              headers: {HttpHeaders.TRANSFER_ENCODING: 'identity'});
        });

        var response = await _get();
        expect(response.headers,
            containsPair(HttpHeaders.TRANSFER_ENCODING, 'chunked'));
        expect(response.bodyBytes, equals([1, 2, 3, 4]));
      });
    });

    test('is preserved when the transfer-encoding header is "chunked"',
        () async {
      await _scheduleServer((request) {
        return new Response.ok(
            new Stream.fromIterable(["2\r\nhi\r\n0\r\n\r\n".codeUnits]),
            headers: {HttpHeaders.TRANSFER_ENCODING: 'chunked'});
      });

      var response = await _get();
      expect(response.headers,
          containsPair(HttpHeaders.TRANSFER_ENCODING, 'chunked'));
      expect(response.body, equals("hi"));
    });

    group('is not added when', () {
      test('content-length is set', () async {
        await _scheduleServer((request) {
          return new Response.ok(
              new Stream.fromIterable([
                [1, 2, 3, 4]
              ]),
              headers: {HttpHeaders.CONTENT_LENGTH: '4'});
        });

        var response = await _get();
        expect(
            response.headers, isNot(contains(HttpHeaders.TRANSFER_ENCODING)));
        expect(response.bodyBytes, equals([1, 2, 3, 4]));
      });

      test('status code is 1xx', () async {
        await _scheduleServer((request) {
          return new Response(123, body: new Stream.empty());
        });

        var response = await _get();
        expect(
            response.headers, isNot(contains(HttpHeaders.TRANSFER_ENCODING)));
        expect(response.body, isEmpty);
      });

      test('status code is 204', () async {
        await _scheduleServer((request) {
          return new Response(204, body: new Stream.empty());
        });

        var response = await _get();
        expect(
            response.headers, isNot(contains(HttpHeaders.TRANSFER_ENCODING)));
        expect(response.body, isEmpty);
      });

      test('status code is 304', () async {
        await _scheduleServer((request) {
          return new Response(304, body: new Stream.empty());
        });

        var response = await _get();
        expect(
            response.headers, isNot(contains(HttpHeaders.TRANSFER_ENCODING)));
        expect(response.body, isEmpty);
      });
    });
  });

  test('respects the "shelf.io.buffer_output" context parameter', () async {
    var controller = new StreamController<String>();
    await _scheduleServer((request) {
      controller.add("Hello, ");

      return new Response.ok(UTF8.encoder.bind(controller.stream),
          context: {"shelf.io.buffer_output": false});
    });

    var request =
        new http.Request("GET", Uri.parse('http://localhost:$_serverPort/'));

    var response = await request.send();
    var stream = new StreamQueue(UTF8.decoder.bind(response.stream));

    var data = await stream.next;
    expect(data, equals("Hello, "));
    controller.add("world!");

    data = await stream.next;
    expect(data, equals("world!"));
    controller.close();
    expect(stream.hasNext, completion(isFalse));
  });

  test('includes the dart:io HttpRequest in the request context', () async {
    await _scheduleServer((request) {
      expect(request.context.containsKey('HttpRequest'), isTrue);
      expect(request.context['HttpRequest'], new isInstanceOf<HttpRequest>());

      HttpRequest httpRequest = request.context['HttpRequest'] as HttpRequest;
      expect(httpRequest.requestedUri, equals(request.requestedUri));

      return syncHandler(request);
    });

    var response = await _get();
    expect(response.statusCode, HttpStatus.OK);
  });

  group('ssl tests', () {
    var securityContext = new SecurityContext()
      ..setTrustedCertificatesBytes(certChainBytes)
      ..useCertificateChainBytes(certChainBytes)
      ..usePrivateKeyBytes(certKeyBytes, password: 'dartdart');

    var sslClient = new HttpClient(context: securityContext);

    Future<HttpClientRequest> _scheduleSecureGet() =>
        sslClient.getUrl(Uri.parse('https://localhost:${_server.port}/'));

    test('secure sync handler returns a value to the client', () async {
      await _scheduleServer(syncHandler, securityContext: securityContext);

      var req = await _scheduleSecureGet();

      var response = await req.close();
      expect(response.statusCode, HttpStatus.OK);
      expect(await response.transform(UTF8.decoder).single, 'Hello from /');
    });

    test('secure async handler returns a value to the client', () async {
      await _scheduleServer(asyncHandler, securityContext: securityContext);

      var req = await _scheduleSecureGet();
      var response = await req.close();
      expect(response.statusCode, HttpStatus.OK);
      expect(await response.transform(UTF8.decoder).single, 'Hello from /');
    });
  });
}

int get _serverPort => _server.port;

HttpServer _server;

Future _scheduleServer(Handler handler,
    {SecurityContext securityContext}) async {
  assert(_server == null);
  _server = await shelf_io.serve(handler, 'localhost', 0,
      securityContext: securityContext);
}

Future<http.Response> _get({Map<String, String> headers}) =>
    http.get('http://localhost:$_serverPort/', headers: headers ?? {});

Future<http.StreamedResponse> _post(
    {Map<String, String> headers, String body}) {
  var request =
      new http.Request('POST', Uri.parse('http://localhost:$_serverPort/'));

  if (headers != null) request.headers.addAll(headers);
  if (body != null) request.body = body;

  return request.send();
}
