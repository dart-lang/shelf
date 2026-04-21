// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bottom_shelf/bottom_shelf.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as parser;
import 'package:shelf/shelf.dart';
import 'package:shelf/src/util.dart';
import 'package:test/test.dart';

import 'test_shared.dart';
import 'test_util.dart';

void main() {
  tearDown(() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
    }
  });

  test('sync handler returns a value to the client', () async {
    await _scheduleServer(syncHandler);

    final response = await _get();
    expect(response.statusCode, HttpStatus.ok);
    expect(response.body, 'Hello from /');
  });

  test('async handler returns a value to the client', () async {
    await _scheduleServer(asyncHandler);

    final response = await _get();
    expect(response.statusCode, HttpStatus.ok);
    expect(response.body, 'Hello from /');
  });

  test('thrown error leads to a 500', () async {
    await _scheduleServer((request) {
      throw UnsupportedError('test');
    });

    final response = await _get();
    expect(response.statusCode, HttpStatus.internalServerError);
    expect(response.body, 'Internal Server Error');
  });

  test('async error leads to a 500', () async {
    await _scheduleServer((request) => Future.error('test'));

    final response = await _get();
    expect(response.statusCode, HttpStatus.internalServerError);
    expect(response.body, 'Internal Server Error');
  });

  test('supports HEAD requests', () async {
    await _scheduleServer(
      (request) => Response(200, headers: {'content-length': '1'}),
    );
    final response = await _head();
    expect(response.headers['content-length'], '1');
  });

  test('Request is populated correctly', () async {
    late Uri uri;

    await _scheduleServer((request) {
      expect(request.method, 'GET');

      expect(request.requestedUri, uri);

      expect(request.url.path, 'foo/bar');
      expect(request.url.pathSegments, ['foo', 'bar']);
      expect(request.protocolVersion, '1.1');
      expect(request.url.query, 'qs=value');
      expect(request.handlerPath, '/');

      return syncHandler(request);
    });

    uri = Uri.http('localhost:$_serverPort', '/foo/bar', {'qs': 'value'});
    final response = await http.get(uri);

    expect(response.statusCode, HttpStatus.ok);
    expect(response.body, 'Hello from /foo/bar');
  });

  test('Request can handle colon in first path segment', () async {
    await _scheduleServer(syncHandler);

    final response = await _get(path: 'user:42');
    expect(response.statusCode, HttpStatus.ok);
    expect(response.body, 'Hello from /user:42');
  });

  test('chunked requests are un-chunked', () async {
    await _scheduleServer(
      expectAsync1((request) async {
        expect(request.contentLength, isNull);
        expect(request.method, 'POST');
        expect(
          request.headers,
          isNot(contains(HttpHeaders.transferEncodingHeader)),
        );
        await expectLater(
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

    final request = http.StreamedRequest(
      'POST',
      Uri.http('localhost:$_serverPort'),
    );
    request.sink.add([1, 2, 3, 4]);
    // ignore: unawaited_futures
    request.sink.close();

    final response = await request.send();
    expect(response.statusCode, HttpStatus.ok);
  });

  test('custom response headers are received by the client', () async {
    await _scheduleServer(
      (request) => Response.ok(
        'Hello from /',
        headers: {'test-header': 'test-value', 'test-list': 'a, b, c'},
      ),
    );

    final response = await _get();
    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers['test-header'], 'test-value');
    expect(response.body, 'Hello from /');
  });

  test('multiple headers are received from the client', () async {
    await _scheduleServer(
      (request) => Response.ok(
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
      ),
    );

    final response = await _get(
      headers: {
        'request-values': ['a', 'b'],
        'set-cookie': ['c', 'd'],
      },
    );
    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers, containsPair('requested-values', 'a, b'));
    expect(response.headers, containsPair('requested-values-length', '1'));
    expect(response.headers, containsPair('set-cookie-values', 'c, d'));
    expect(response.headers, containsPair('set-cookie-values-length', '2'));
  });

  test('custom status code is received by the client', () async {
    await _scheduleServer((request) => Response(299, body: 'Hello from /'));

    final response = await _get();
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

    final headers = {
      'custom-header': 'client value',
      'multi-header': 'foo,bar,baz',
    };

    final response = await _get(headers: headers);
    expect(response.statusCode, HttpStatus.ok);
    expect(response.body, 'Hello from /');
  });

  test('post with empty content', () async {
    await _scheduleServer((request) async {
      expect(request.mimeType, isNull);
      expect(request.encoding, isNull);
      expect(request.method, 'POST');
      expect(request.contentLength, 0);

      final body = await request.readAsString();
      expect(body, '');
      return syncHandler(request);
    });

    final response = await _post();
    expect(response.statusCode, HttpStatus.ok);
    await expectLater(
      response.stream.bytesToString(),
      completion('Hello from /'),
    );
  });

  test('post with request content', () async {
    await _scheduleServer((request) async {
      expect(request.mimeType, 'text/plain');
      expect(request.encoding, utf8);
      expect(request.method, 'POST');
      expect(request.contentLength, 9);

      final body = await request.readAsString();
      expect(body, 'test body');
      return syncHandler(request);
    });

    final response = await _post(body: 'test body');
    expect(response.statusCode, HttpStatus.ok);
    await expectLater(
      response.stream.bytesToString(),
      completion('Hello from /'),
    );
  });

  test('supports request hijacking', () async {
    await _scheduleServer((request) {
      expect(request.method, 'POST');

      request.hijack(
        expectAsync1((channel) async {
          await expectLater(
            channel.stream.first,
            completion(equals('Hello'.codeUnits)),
          );

          channel.sink.add(
            'HTTP/1.1 404 Not Found\r\n'
                    'date: Mon, 23 May 2005 22:38:34 GMT\r\n'
                    'Content-Length: 13\r\n'
                    '\r\n'
                    'Hello, world!'
                .codeUnits,
          );
          await channel.sink.close();
        }),
      );
    });

    final response = await _post(body: 'Hello');

    expect(response.statusCode, HttpStatus.notFound);
    expect(response.headers['date'], 'Mon, 23 May 2005 22:38:34 GMT');
    await expectLater(
      response.stream.bytesToString(),
      completion(equals('Hello, world!')),
    );
  });

  test(
    'reports an error if a HijackException is thrown without hijacking',
    () async {
      await _scheduleServer((request) => throw const HijackException());

      final response = await _get();
      expect(response.statusCode, HttpStatus.internalServerError);
    },
    skip: 'RawShelfServer destroys socket on error currently',
  );

  test('passes asynchronous exceptions to the parent error zone', () async {
    await runZonedGuarded(
      () async {
        final server = await RawShelfServer.serve(
          (request) {
            Future(() => throw StateError('oh no'));
            return syncHandler(request);
          },
          'localhost',
          0,
          // ignore: only_throw_errors
          onAsyncError: (e, st) => throw e,
        );
        addTearDown(server.close);

        final response = await http.get(
          Uri.http('localhost:${server.port}', '/'),
        );
        expect(response.statusCode, HttpStatus.ok);
        expect(response.body, 'Hello from /');
      },
      expectAsync2((error, stack) {
        expect(error, isOhNoStateError);
      }),
    );
  });

  test("doesn't pass asynchronous exceptions to the root error zone", () async {
    RawShelfServer? server;
    final response = await Zone.root.run(() async {
      server = await RawShelfServer.serve(
        (request) {
          Future(() => throw StateError('oh no'));
          return syncHandler(request);
        },
        'localhost',
        0,
      );

      return http.get(Uri.http('localhost:${server!.port}', '/'));
    });
    if (server != null) {
      addTearDown(server!.close);
    }

    expect(response.statusCode, HttpStatus.ok);
    expect(response.body, 'Hello from /');
  });

  test(
    'a bad HTTP host request results in a 500 response',
    () async {
      await _scheduleServer(syncHandler);

      final socket = await Socket.connect('localhost', _serverPort);

      try {
        socket.write('GET / HTTP/1.1\r\n');
        socket.write('Host: ^^super bad !@#host\r\n');
        socket.write('\r\n');
      } finally {
        await socket.close();
      }

      expect(
        await utf8.decodeStream(socket),
        contains('500 Internal Server Error'),
      );
    },
    skip: 'RawShelfServer destroys socket on parse error currently',
  );

  test('a bad HTTP URL request results in a 400 response', () async {
    await _scheduleServer(syncHandler);
    final socket = await Socket.connect('localhost', _serverPort);

    try {
      socket.write('GET /#/ HTTP/1.1\r\n');
      socket.write('Host: localhost\r\n');
      socket.write('\r\n');
    } finally {
      await socket.close();
    }

    expect(await utf8.decodeStream(socket), isABadRequestResponse);
  });

  test(
    'a request with whitespace in header key results in a 400 response',
    () async {
      await _scheduleServer(syncHandler);
      final socket = await Socket.connect('localhost', _serverPort);

      try {
        socket.write('GET / HTTP/1.1\r\n');
        socket.write('Host : localhost\r\n');
        socket.write('\r\n');
      } finally {
        await socket.close();
      }

      expect(await utf8.decodeStream(socket), isABadRequestResponse);
    },
  );

  test(
    'a request without Host header in HTTP/1.1 results in a 400 response',
    () async {
      await _scheduleServer(syncHandler);
      final socket = await Socket.connect('localhost', _serverPort);

      try {
        socket.write('GET / HTTP/1.1\r\n');
        socket.write('\r\n');
      } finally {
        await socket.close();
      }

      expect(await utf8.decodeStream(socket), isABadRequestResponse);
    },
  );

  test(
    'a request with path not starting with slash handles it correctly',
    () async {
      await _scheduleServer((request) {
        expect(request.url.path, 'foo');
        return Response.ok('Hello');
      });
      final socket = await Socket.connect('localhost', _serverPort);

      try {
        socket.write('GET foo HTTP/1.1\r\n');
        socket.write('Host: localhost\r\n');
        socket.write('Connection: close\r\n');
        socket.write('\r\n');
      } finally {
        await socket.close();
      }

      final response = await utf8.decodeStream(socket);
      expect(response, contains('200 OK'));
    },
  );

  test('non-ASCII character in header key results in a 400 response', () async {
    await _scheduleServer(syncHandler);
    final socket = await Socket.connect('localhost', _serverPort);

    try {
      socket.write('GET / HTTP/1.1\r\n');
      socket.write('Host: localhost\r\n');
      socket.add([
        88,
        45,
        84,
        101,
        115,
        116,
        255,
        58,
        32,
        118,
        97,
        108,
        117,
        101,
        13,
        10,
      ]);
      socket.write('Connection: close\r\n');
      socket.write('\r\n');
    } finally {
      await socket.close();
    }

    expect(await utf8.decodeStream(socket), isABadRequestResponse);
  });

  test('a request with invalid character (brackets) in header key results '
      'in a 400 response', () async {
    await _scheduleServer(syncHandler);
    final socket = await Socket.connect('localhost', _serverPort);

    try {
      socket.write('GET / HTTP/1.1\r\n');
      socket.write('Host: localhost\r\n');
      socket.write('Bad[Name]: value\r\n');
      socket.write('Connection: close\r\n');
      socket.write('\r\n');
    } finally {
      await socket.close();
    }

    expect(await utf8.decodeStream(socket), isABadRequestResponse);
  });

  test(
    'a request with obs-fold in headers results in a 400 response',
    () async {
      await _scheduleServer(syncHandler);
      final socket = await Socket.connect('localhost', _serverPort);

      try {
        socket.write('GET / HTTP/1.1\r\n');
        socket.write('Host: localhost\r\n');
        socket.write('X-Test: value\r\n');
        socket.write(' continued\r\n');
        socket.write('Connection: close\r\n');
        socket.write('\r\n');
      } finally {
        await socket.close();
      }

      expect(await utf8.decodeStream(socket), isABadRequestResponse);
    },
  );

  test('a request with empty header name results in a 400 response', () async {
    await _scheduleServer(syncHandler);
    final socket = await Socket.connect('localhost', _serverPort);

    try {
      socket.write('GET / HTTP/1.1\r\n');
      socket.write('Host: localhost\r\n');
      socket.write(': empty-name\r\n');
      socket.write('Connection: close\r\n');
      socket.write('\r\n');
    } finally {
      await socket.close();
    }

    expect(await utf8.decodeStream(socket), isABadRequestResponse);
  });

  test(
    'a request with header line without colon results in a 400 response',
    () async {
      await _scheduleServer(syncHandler);
      final socket = await Socket.connect('localhost', _serverPort);

      try {
        socket.write('GET / HTTP/1.1\r\n');
        socket.write('Host: localhost\r\n');
        socket.write('NoColonHere\r\n');
        socket.write('Connection: close\r\n');
        socket.write('\r\n');
      } finally {
        await socket.close();
      }

      expect(await utf8.decodeStream(socket), isABadRequestResponse);
    },
  );

  test(
    'a request with duplicate Host headers results in a 400 response',
    () async {
      await _scheduleServer(syncHandler);
      final socket = await Socket.connect('localhost', _serverPort);

      try {
        socket.write('GET / HTTP/1.1\r\n');
        socket.write('Host: localhost\r\n');
        socket.write('Host: other.localhost\r\n');
        socket.write('Connection: close\r\n');
        socket.write('\r\n');
      } finally {
        await socket.close();
      }

      expect(await utf8.decodeStream(socket), isABadRequestResponse);
    },
  );

  test(
    'a request with non-numeric Content-Length results in a 400 response',
    () async {
      await _scheduleServer(syncHandler);
      final socket = await Socket.connect('localhost', _serverPort);

      try {
        socket.write('POST / HTTP/1.1\r\n');
        socket.write('Host: localhost\r\n');
        socket.write('Content-Length: abc\r\n');
        socket.write('Connection: close\r\n');
        socket.write('\r\n');
      } finally {
        await socket.close();
      }

      expect(await utf8.decodeStream(socket), isABadRequestResponse);
    },
  );

  test(
    'Content-Length containing plus sign results in a 400 response',
    () async {
      await _scheduleServer(syncHandler);
      final socket = await Socket.connect('localhost', _serverPort);

      try {
        socket.write('POST / HTTP/1.1\r\n');
        socket.write('Host: localhost\r\n');
        socket.write('Content-Length: +5\r\n');
        socket.write('Connection: close\r\n');
        socket.write('\r\n');
        socket.write('hello');
      } finally {
        await socket.close();
      }

      expect(await utf8.decodeStream(socket), isABadRequestResponse);
    },
  );

  test(
    'a request with unknown Transfer-Encoding results in a 501 response',
    () async {
      await _scheduleServer(syncHandler);
      final socket = await Socket.connect('localhost', _serverPort);

      try {
        socket.write('POST / HTTP/1.1\r\n');
        socket.write('Host: localhost\r\n');
        socket.write('Transfer-Encoding: gzip\r\n');
        socket.write('Connection: close\r\n');
        socket.write('\r\n');
      } finally {
        await socket.close();
      }

      final response = await utf8.decodeStream(socket);
      expect(response, contains('501 Not Implemented'));
    },
  );

  test(
    'a request with invalid HTTP version results in a 400 response',
    () async {
      await _scheduleServer(syncHandler);
      final socket = await Socket.connect('localhost', _serverPort);

      try {
        socket.write('GET / HTTP/9.9\r\n');
        socket.write('Host: localhost\r\n');
        socket.write('Connection: close\r\n');
        socket.write('\r\n');
      } finally {
        await socket.close();
      }

      expect(await utf8.decodeStream(socket), isABadRequestResponse);
    },
  );

  test(
    'a request with asterisk-form for GET results in a 400 response',
    () async {
      await _scheduleServer(syncHandler);
      final socket = await Socket.connect('localhost', _serverPort);

      try {
        socket.write('GET * HTTP/1.1\r\n');
        socket.write('Host: localhost\r\n');
        socket.write('Connection: close\r\n');
        socket.write('\r\n');
      } finally {
        await socket.close();
      }

      expect(await utf8.decodeStream(socket), isABadRequestResponse);
    },
  );

  test(
    'a request with HTTP version missing minor digit results in a 400 response',
    () async {
      await _scheduleServer(syncHandler);
      final socket = await Socket.connect('localhost', _serverPort);

      try {
        socket.write('GET / HTTP/1\r\n');
        socket.write('Host: localhost\r\n');
        socket.write('Connection: close\r\n');
        socket.write('\r\n');
      } finally {
        await socket.close();
      }

      expect(await utf8.decodeStream(socket), isABadRequestResponse);
    },
  );

  group('date header', () {
    test(
      'is sent by default',
      skip: 'RawShelfServer does not send date header by default yet',
      () async {
        await _scheduleServer(syncHandler);

        final beforeRequest = DateTime.now().subtract(
          const Duration(seconds: 1),
        );

        final response = await _get();
        expect(response.headers, contains('date'));
        final responseDate = parser.parseHttpDate(response.headers['date']!);

        expect(responseDate.isAfter(beforeRequest), isTrue);
        expect(responseDate.isBefore(DateTime.now()), isTrue);
      },
    );

    test('defers to header in response', () async {
      final date = DateTime.utc(1981, 6, 5);
      await _scheduleServer(
        (request) => Response.ok(
          'test',
          headers: {HttpHeaders.dateHeader: parser.formatHttpDate(date)},
        ),
      );

      final response = await _get();
      expect(response.headers, contains('date'));
      final responseDate = parser.parseHttpDate(response.headers['date']!);
      expect(responseDate, date);
    });
  });

  group('X-Powered-By header', () {
    const poweredBy = 'x-powered-by';
    test(
      'defaults to "Dart with package:shelf"',
      () async {
        await _scheduleServer(syncHandler);

        final response = await _get();
        expect(
          response.headers,
          containsPair(poweredBy, 'Dart with package:shelf'),
        );
      },
      skip: 'RawShelfServer does not send X-Powered-By header by default yet',
    );
  });

  group('chunked coding', () {
    test('is added when the transfer-encoding header is unset', () async {
      await _scheduleServer(
        (request) => Response.ok(
          Stream.fromIterable([
            [1, 2, 3, 4],
          ]),
        ),
      );

      final response = await _get();
      expect(
        response.headers,
        containsPair(HttpHeaders.transferEncodingHeader, 'chunked'),
      );
      expect(response.bodyBytes, equals([1, 2, 3, 4]));
    });
  });

  test(
    'includes the dart:io HttpConnectionInfo in request context',
    () async {
      await _scheduleServer((request) {
        expect(
          request.context,
          containsPair('shelf.io.connection_info', isA<HttpConnectionInfo>()),
        );
        return syncHandler(request);
      });

      final response = await _get();
      expect(response.statusCode, HttpStatus.ok);
    },
    skip: 'RawShelfServer does not provide HttpConnectionInfo yet',
  );
}

int get _serverPort => _server!.port;

RawShelfServer? _server;

Future<void> _scheduleServer(Handler handler) async {
  assert(_server == null);
  _server = await RawShelfServer.serve(handler, 'localhost', 0);
}

Future<http.Response> _get({
  Map<String, /* String | List<String> */ Object>? headers,
  String path = '',
}) =>
    _request((client, url) => client.getUrl(url), headers: headers, path: path);

Future<http.Response> _head({
  Map<String, /* String | List<String> */ Object>? headers,
  String path = '',
}) => _request(
  (client, url) => client.headUrl(url),
  headers: headers,
  path: path,
);

Future<http.Response> _request(
  Future<HttpClientRequest> Function(HttpClient, Uri) request, {
  Map<String, /* String | List<String> */ Object>? headers,
  String path = '',
}) async {
  final client = HttpClient();
  try {
    final rq = await request(client, Uri.http('localhost:$_serverPort', path));
    if (headers != null) {
      for (var entry in headers.entries) {
        final value = entry.value;
        if (value is List) {
          for (var v in value) {
            rq.headers.add(entry.key, v as Object);
          }
        } else {
          rq.headers.add(entry.key, value);
        }
      }
    }
    final rs = await rq.close();
    final rsHeaders = <String, String>{};
    rs.headers.forEach((name, values) {
      rsHeaders[name] = joinHeaderValues(values)!;
    });
    return await http.Response.fromStream(
      http.StreamedResponse(rs, rs.statusCode, headers: rsHeaders),
    );
  } finally {
    client.close(force: true);
  }
}

Future<http.StreamedResponse> _post({
  Map<String, String>? headers,
  String? body,
}) {
  final request = http.Request('POST', Uri.http('localhost:$_serverPort'));

  if (headers != null) request.headers.addAll(headers);
  if (body != null) request.body = body;

  return request.send();
}
