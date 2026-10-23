// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as parser;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'conformance_server.dart';
import 'ssl_certs.dart';

/// Runs the shelf adapter conformance tests against the adapter that [serve]
/// starts.
///
/// [defaultPoweredByHeader] is the `X-Powered-By` value the adapter sends when
/// [ServeOptions.overridesPoweredByHeader] is `false`.
///
/// Set [supportsSecurityContext] to `false` if the adapter can't serve HTTPS
/// from a [ServeOptions.securityContext].
///
/// Set [rejectsMalformedHost] to `false` if the adapter does not respond
/// `400` to a request with a malformed `Host` header as required by
/// RFC 9112 section 3.2. The corresponding test is skipped. `shelf_io`
/// responds `500` because `dart:io` does.
void testAll(
  ServeCallback serve, {
  required String defaultPoweredByHeader,
  bool supportsSecurityContext = true,
  bool rejectsMalformedHost = true,
}) {
  ConformanceServer? server;

  int serverPort() => server!.port;

  Future<void> scheduleServer(
    Handler handler, {
    ServeOptions options = const ServeOptions(),
  }) async {
    assert(server == null);
    server = await serve(handler, options);
  }

  tearDown(() async {
    if (server != null) {
      await server!.close();
      server = null;
    }
  });

  Future<http.Response> get({
    Map<String, /* String | List<String> */ Object>? headers,
    String path = '',
  }) => _request(
    serverPort(),
    (client, url) => client.getUrl(url),
    headers: headers,
    path: path,
  );

  Future<http.Response> head() =>
      _request(serverPort(), (client, url) => client.headUrl(url));

  Future<http.StreamedResponse> post({String? body}) {
    var request = http.Request(
      'POST',
      Uri.http('localhost:${serverPort()}', ''),
    );

    if (body != null) request.body = body;

    return request.send();
  }

  test('sync handler returns a value to the client', () async {
    await scheduleServer(_syncHandler);

    var response = await get();
    expect(response.statusCode, HttpStatus.ok);
    expect(response.body, 'Hello from /');
  });

  test('async handler returns a value to the client', () async {
    await scheduleServer(_asyncHandler);

    var response = await get();
    expect(response.statusCode, HttpStatus.ok);
    expect(response.body, 'Hello from /');
  });

  test('thrown error leads to a 500', () async {
    await scheduleServer((request) {
      throw UnsupportedError('test');
    });

    var response = await get();
    expect(response.statusCode, HttpStatus.internalServerError);
    expect(response.body, 'Internal Server Error');
  });

  test('async error leads to a 500', () async {
    await scheduleServer((request) {
      return Future.error('test');
    });

    var response = await get();
    expect(response.statusCode, HttpStatus.internalServerError);
    expect(response.body, 'Internal Server Error');
  });

  test('supports HEAD requests', () async {
    await scheduleServer((request) {
      return Response(200, headers: {'content-length': '1'});
    });
    var response = await head();
    expect(response.headers['content-length'], '1');
  });

  test('Request is populated correctly', () async {
    late Uri uri;

    await scheduleServer((request) {
      expect(request.method, 'GET');

      expect(request.requestedUri, uri);

      expect(request.url.path, 'foo/bar');
      expect(request.url.pathSegments, ['foo', 'bar']);
      expect(request.protocolVersion, '1.1');
      expect(request.url.query, 'qs=value');
      expect(request.handlerPath, '/');

      return _syncHandler(request);
    });

    uri = Uri.http('localhost:${serverPort()}', '/foo/bar', {'qs': 'value'});
    var response = await http.get(uri);

    expect(response.statusCode, HttpStatus.ok);
    expect(response.body, 'Hello from /foo/bar');
  });

  test('Request can handle colon in first path segment', () async {
    await scheduleServer(_syncHandler);

    var response = await get(path: 'user:42');
    expect(response.statusCode, HttpStatus.ok);
    expect(response.body, 'Hello from /user:42');
  });

  test('chunked requests are un-chunked', () async {
    await scheduleServer(
      expectAsync1((request) {
        expect(request.contentLength, isNull);
        expect(request.method, 'POST');
        expect(
          request.headers,
          isNot(contains(HttpHeaders.transferEncodingHeader)),
        );
        expect(
          request.read().toList(),
          completion(
            equals([
              [1, 2, 3, 4],
            ]),
          ),
        );
        return Response.ok(null);
      }),
    );

    var request = http.StreamedRequest(
      'POST',
      Uri.http('localhost:${serverPort()}', ''),
    );
    request.sink.add([1, 2, 3, 4]);
    // ignore: unawaited_futures
    request.sink.close();

    var response = await request.send();
    expect(response.statusCode, HttpStatus.ok);
  });

  test('custom response headers are received by the client', () async {
    await scheduleServer((request) {
      return Response.ok(
        'Hello from /',
        headers: {'test-header': 'test-value', 'test-list': 'a, b, c'},
      );
    });

    var response = await get();
    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers['test-header'], 'test-value');
    expect(response.body, 'Hello from /');
  });

  test('multiple headers are received from the client', () async {
    await scheduleServer((request) {
      return Response.ok(
        'Hello from /',
        headers: {
          'requested-values': request.headersAll['request-values']!,
          'requested-values-length': request
              .headersAll['request-values']!
              .length
              .toString(),
          'set-cookie-values': request.headersAll['set-cookie']!,
          'set-cookie-values-length': request.headersAll['set-cookie']!.length
              .toString(),
        },
      );
    });

    final response = await get(
      headers: {
        'request-values': ['a', 'b'],
        'set-cookie': ['c', 'd'],
      },
    );
    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers['requested-values'], 'a, b');
    expect(response.headers['requested-values-length'], '1');
    expect(response.headers['set-cookie-values'], 'c, d');
    expect(response.headers['set-cookie-values-length'], '2');
  });

  test('custom status code is received by the client', () async {
    await scheduleServer((request) {
      return Response(299, body: 'Hello from /');
    });

    var response = await get();
    expect(response.statusCode, 299);
    expect(response.body, 'Hello from /');
  });

  test('custom request headers are received by the handler', () async {
    await scheduleServer((request) {
      expect(request.headers, containsPair('custom-header', 'client value'));

      // dart:io HttpServer splits multi-value headers into an array
      // validate that they are combined correctly
      expect(request.headers, containsPair('multi-header', 'foo,bar,baz'));
      return _syncHandler(request);
    });

    var headers = {
      'custom-header': 'client value',
      'multi-header': 'foo,bar,baz',
    };

    var response = await get(headers: headers);
    expect(response.statusCode, HttpStatus.ok);
    expect(response.body, 'Hello from /');
  });

  test('post with empty content', () async {
    await scheduleServer((request) async {
      expect(request.mimeType, isNull);
      expect(request.encoding, isNull);
      expect(request.method, 'POST');
      expect(request.contentLength, 0);

      var body = await request.readAsString();
      expect(body, '');
      return _syncHandler(request);
    });

    var response = await post();
    expect(response.statusCode, HttpStatus.ok);
    expect(response.stream.bytesToString(), completion('Hello from /'));
  });

  test('post with request content', () async {
    await scheduleServer((request) async {
      expect(request.mimeType, 'text/plain');
      expect(request.encoding, utf8);
      expect(request.method, 'POST');
      expect(request.contentLength, 9);

      var body = await request.readAsString();
      expect(body, 'test body');
      return _syncHandler(request);
    });

    var response = await post(body: 'test body');
    expect(response.statusCode, HttpStatus.ok);
    expect(response.stream.bytesToString(), completion('Hello from /'));
  });

  test('supports request hijacking', () async {
    await scheduleServer((request) {
      expect(request.method, 'POST');

      request.hijack(
        expectAsync1((channel) {
          expect(channel.stream.first, completion(equals('Hello'.codeUnits)));

          channel.sink.add(
            'HTTP/1.1 404 Not Found\r\n'
                    'date: Mon, 23 May 2005 22:38:34 GMT\r\n'
                    'Content-Length: 13\r\n'
                    '\r\n'
                    'Hello, world!'
                .codeUnits,
          );
          channel.sink.close();
        }),
      );
    });

    var response = await post(body: 'Hello');
    expect(response.statusCode, HttpStatus.notFound);
    expect(response.headers['date'], 'Mon, 23 May 2005 22:38:34 GMT');
    expect(
      response.stream.bytesToString(),
      completion(equals('Hello, world!')),
    );
  });

  test(
    'reports an error if a HijackException is thrown without hijacking',
    () async {
      await scheduleServer((request) => throw const HijackException());

      var response = await get();
      expect(response.statusCode, HttpStatus.internalServerError);
    },
  );

  test('passes asynchronous exceptions to the parent error zone', () async {
    await runZonedGuarded(
      () async {
        await scheduleServer((request) {
          Future(() => throw StateError('oh no'));
          return _syncHandler(request);
        });

        var response = await http.get(
          Uri.http('localhost:${serverPort()}', '/'),
        );
        expect(response.statusCode, HttpStatus.ok);
        expect(response.body, 'Hello from /');
      },
      expectAsync2((error, stack) {
        expect(error, _isOhNoStateError);
      }),
    );
  });

  test("doesn't pass asynchronous exceptions to the root error zone", () async {
    var response = await Zone.root.run(() async {
      await scheduleServer((request) {
        Future(() => throw StateError('oh no'));
        return _syncHandler(request);
      });

      return http.get(Uri.http('localhost:${serverPort()}', '/'));
    });

    expect(response.statusCode, HttpStatus.ok);
    expect(response.body, 'Hello from /');
  });

  test(
    'a malformed HTTP host request results in a 400 response',
    () async {
      await scheduleServer(_syncHandler);

      var socket = await Socket.connect('localhost', serverPort());

      try {
        socket.write('GET / HTTP/1.1\r\n');
        socket.write('Host: ^^super bad !@#host\r\n');
        socket.write('\r\n');
      } finally {
        await socket.close();
      }

      expect(await utf8.decodeStream(socket), startsWith('HTTP/1.1 400 '));
    },
    skip: rejectsMalformedHost
        ? false
        : 'adapter does not respond 400 to a malformed Host header '
              '(RFC 9112 section 3.2)',
  );

  test('a bad HTTP URL request results in a 400 response', () async {
    await scheduleServer(_syncHandler);
    final socket = await Socket.connect('localhost', serverPort());

    try {
      socket.write('GET /#/ HTTP/1.1\r\n');
      socket.write('Host: localhost\r\n');
      socket.write('\r\n');
    } finally {
      await socket.close();
    }

    expect(await utf8.decodeStream(socket), contains('400 Bad Request'));
  });

  group('date header', () {
    test('is sent by default', () async {
      await scheduleServer(_syncHandler);

      // Update beforeRequest to be one second earlier. HTTP dates only have
      // second-level granularity and the request will likely take less than a
      // second.
      var beforeRequest = DateTime.now().subtract(const Duration(seconds: 1));

      var response = await get();
      expect(response.headers, contains('date'));
      var responseDate = parser.parseHttpDate(response.headers['date']!);

      expect(responseDate.isAfter(beforeRequest), isTrue);
      expect(responseDate.isBefore(DateTime.now()), isTrue);
    });

    test('defers to header in response', () async {
      var date = DateTime.utc(1981, 6, 5);
      await scheduleServer((request) {
        return Response.ok(
          'test',
          headers: {HttpHeaders.dateHeader: parser.formatHttpDate(date)},
        );
      });

      var response = await get();
      expect(response.headers, contains('date'));
      var responseDate = parser.parseHttpDate(response.headers['date']!);
      expect(responseDate, date);
    });
  });

  group('X-Powered-By header', () {
    const poweredBy = 'x-powered-by';
    test('defaults to "$defaultPoweredByHeader"', () async {
      await scheduleServer(_syncHandler);

      var response = await get();
      expect(response.headers, containsPair(poweredBy, defaultPoweredByHeader));
    });

    test('defers to header in response when default', () async {
      await scheduleServer((request) {
        return Response.ok('test', headers: {poweredBy: 'myServer'});
      });

      var response = await get();
      expect(response.headers, containsPair(poweredBy, 'myServer'));
    });

    test('can be set at the server level', () async {
      await scheduleServer(
        _syncHandler,
        options: const ServeOptions.poweredBy('ourServer'),
      );
      var response = await get();
      expect(response.headers, containsPair(poweredBy, 'ourServer'));
    });

    test('defers to header in response when set at the server level', () async {
      await scheduleServer((request) {
        return Response.ok('test', headers: {poweredBy: 'myServer'});
      }, options: const ServeOptions.poweredBy('ourServer'));

      var response = await get();
      expect(response.headers, containsPair(poweredBy, 'myServer'));
    });

    test('is omitted when set to null', () async {
      await scheduleServer(
        _syncHandler,
        options: const ServeOptions.poweredBy(null),
      );

      var response = await get();
      expect(response.headers, isNot(contains(poweredBy)));
    });
  });

  group('chunked coding', () {
    group('is added when the transfer-encoding header is', () {
      test('unset', () async {
        await scheduleServer((request) {
          return Response.ok(
            Stream.fromIterable([
              [1, 2, 3, 4],
            ]),
          );
        });

        var response = await get();
        expect(
          response.headers,
          containsPair(HttpHeaders.transferEncodingHeader, 'chunked'),
        );
        expect(response.bodyBytes, equals([1, 2, 3, 4]));
      });

      test('"identity"', () async {
        await scheduleServer((request) {
          return Response.ok(
            Stream.fromIterable([
              [1, 2, 3, 4],
            ]),
            headers: {HttpHeaders.transferEncodingHeader: 'identity'},
          );
        });

        var response = await get();
        expect(
          response.headers,
          containsPair(HttpHeaders.transferEncodingHeader, 'chunked'),
        );
        expect(response.bodyBytes, equals([1, 2, 3, 4]));
      });
    });

    test(
      'is preserved when the transfer-encoding header is "chunked"',
      () async {
        await scheduleServer((request) {
          return Response.ok(
            Stream.fromIterable(['2\r\nhi\r\n0\r\n\r\n'.codeUnits]),
            headers: {HttpHeaders.transferEncodingHeader: 'chunked'},
          );
        });

        var response = await get();
        expect(
          response.headers,
          containsPair(HttpHeaders.transferEncodingHeader, 'chunked'),
        );
        expect(response.body, equals('hi'));
      },
    );

    group('is not added when', () {
      test('content-length is set', () async {
        await scheduleServer((request) {
          return Response.ok(
            Stream.fromIterable([
              [1, 2, 3, 4],
            ]),
            headers: {HttpHeaders.contentLengthHeader: '4'},
          );
        });

        var response = await get();
        expect(
          response.headers,
          isNot(contains(HttpHeaders.transferEncodingHeader)),
        );
        expect(response.bodyBytes, equals([1, 2, 3, 4]));
      });

      test('status code is 1xx', () async {
        await scheduleServer((request) {
          return Response(123, body: const Stream<List<int>>.empty());
        });

        var response = await get();
        expect(
          response.headers,
          isNot(contains(HttpHeaders.transferEncodingHeader)),
        );
        expect(response.body, isEmpty);
      });

      test('status code is 204', () async {
        await scheduleServer((request) {
          return Response(204, body: const Stream<List<int>>.empty());
        });

        var response = await get();
        expect(
          response.headers,
          isNot(contains(HttpHeaders.transferEncodingHeader)),
        );
        expect(response.body, isEmpty);
      });

      test('status code is 304', () async {
        await scheduleServer((request) {
          return Response(304, body: const Stream<List<int>>.empty());
        });

        var response = await get();
        expect(
          response.headers,
          isNot(contains(HttpHeaders.transferEncodingHeader)),
        );
        expect(response.body, isEmpty);
      });
    });
  });

  test('includes the dart:io HttpConnectionInfo in request context', () async {
    await scheduleServer((request) {
      expect(
        request.context,
        containsPair('shelf.io.connection_info', isA<HttpConnectionInfo>()),
      );

      var connectionInfo =
          request.context['shelf.io.connection_info'] as HttpConnectionInfo;
      expect(connectionInfo.remoteAddress, equals(server!.address));
      expect(connectionInfo.localPort, equals(server!.port));

      return _syncHandler(request);
    });

    var response = await get();
    expect(response.statusCode, HttpStatus.ok);
  });

  test(
    'resolves connection info lazily, consistently, and through change()',
    () async {
      await scheduleServer((request) {
        var info =
            request.context['shelf.io.connection_info'] as HttpConnectionInfo;

        // All three fields resolve, including remotePort, which is only
        // available from the socket.
        expect(info.remoteAddress, equals(server!.address));
        expect(info.localPort, equals(server!.port));
        expect(info.remotePort, greaterThan(0));

        // Reading again is served from the cache, so the values cannot drift.
        expect(info.remoteAddress, equals(info.remoteAddress));
        expect(info.remotePort, equals(info.remotePort));
        expect(info.localPort, equals(info.localPort));

        // Middleware copies context, so the same instance has to keep working
        // after the request is rebuilt.
        var changed = request.change(headers: {'x-marker': 'set'});
        var copied =
            changed.context['shelf.io.connection_info'] as HttpConnectionInfo;
        expect(copied, same(info));
        expect(copied.remotePort, equals(info.remotePort));

        return _syncHandler(request);
      });

      var response = await get();
      expect(response.statusCode, HttpStatus.ok);
    },
  );

  group('ssl tests', () {
    var securityContext = SecurityContext()
      ..setTrustedCertificatesBytes(certChainBytes)
      ..useCertificateChainBytes(certChainBytes)
      ..usePrivateKeyBytes(certKeyBytes, password: 'dartdart');

    var sslClient = HttpClient(context: securityContext)
      ..badCertificateCallback = (cert, host, port) => true;

    Future<HttpClientRequest> scheduleSecureGet() =>
        sslClient.getUrl(Uri.https('localhost:${server!.port}', ''));

    test('secure sync handler returns a value to the client', () async {
      await scheduleServer(
        _syncHandler,
        options: ServeOptions(securityContext: securityContext),
      );

      var req = await scheduleSecureGet();

      var response = await req.close();
      expect(response.statusCode, HttpStatus.ok);
      expect(
        await response.cast<List<int>>().transform(utf8.decoder).single,
        'Hello from /',
      );
    });

    test('secure async handler returns a value to the client', () async {
      await scheduleServer(
        _asyncHandler,
        options: ServeOptions(securityContext: securityContext),
      );

      var req = await scheduleSecureGet();
      var response = await req.close();
      expect(response.statusCode, HttpStatus.ok);
      expect(
        await response.cast<List<int>>().transform(utf8.decoder).single,
        'Hello from /',
      );
    });
  }, skip: supportsSecurityContext ? false : 'HTTPS is not supported');
}

/// Replies with a status code 200 and `Hello from ${request.url.path}`.
Response _syncHandler(Request request) =>
    Response.ok('Hello from ${request.requestedUri.path}');

/// Calls [_syncHandler] and wraps the response in a [Future].
Future<Response> _asyncHandler(Request request) =>
    Future(() => _syncHandler(request));

final _isOhNoStateError = isA<StateError>().having(
  (p0) => p0.message,
  'message',
  'oh no',
);

Future<http.Response> _request(
  int port,
  Future<HttpClientRequest> Function(HttpClient, Uri) request, {
  Map<String, /* String | List<String> */ Object>? headers,
  String path = '',
}) async {
  // TODO: use http.Client once it supports sending/receiving multiple headers.
  final client = HttpClient();
  try {
    final rq = await request(client, Uri.http('localhost:$port', path));
    headers?.forEach((key, value) {
      rq.headers.add(key, value);
    });
    final rs = await rq.close();
    final rsHeaders = <String, String>{};
    rs.headers.forEach((name, values) {
      rsHeaders[name] = values.join(',');
    });
    return await http.Response.fromStream(
      http.StreamedResponse(rs, rs.statusCode, headers: rsHeaders),
    );
  } finally {
    client.close(force: true);
  }
}
