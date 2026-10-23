// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bottom_shelf/bottom_shelf.dart';
import 'package:bottom_shelf/src/constants.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../support/test_shared.dart';

void main() {
  test(
    'a request with whitespace in header key results in a 400 response',
    () async {
      final port = await _scheduleServer(_syncHandler);
      final socket = await Socket.connect('localhost', port);

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
      final port = await _scheduleServer(_syncHandler);
      final socket = await Socket.connect('localhost', port);

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
      final port = await _scheduleServer((request) {
        expect(request.url.path, 'foo');
        return Response.ok('Hello');
      });
      final socket = await Socket.connect('localhost', port);

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
    final port = await _scheduleServer(_syncHandler);
    final socket = await Socket.connect('localhost', port);

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
    final port = await _scheduleServer(_syncHandler);
    final socket = await Socket.connect('localhost', port);

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
      final port = await _scheduleServer(_syncHandler);
      final socket = await Socket.connect('localhost', port);

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
    final port = await _scheduleServer(_syncHandler);
    final socket = await Socket.connect('localhost', port);

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
      final port = await _scheduleServer(_syncHandler);
      final socket = await Socket.connect('localhost', port);

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
      final port = await _scheduleServer(_syncHandler);
      final socket = await Socket.connect('localhost', port);

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
      final port = await _scheduleServer(_syncHandler);
      final socket = await Socket.connect('localhost', port);

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
      final port = await _scheduleServer(_syncHandler);
      final socket = await Socket.connect('localhost', port);

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
      final port = await _scheduleServer(_syncHandler);
      final socket = await Socket.connect('localhost', port);

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
      final port = await _scheduleServer(_syncHandler);
      final socket = await Socket.connect('localhost', port);

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
      final port = await _scheduleServer(_syncHandler);
      final socket = await Socket.connect('localhost', port);

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
      final port = await _scheduleServer(_syncHandler);
      final socket = await Socket.connect('localhost', port);

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

  test(
    'HTTP version containing leading zeros results in a 400 response',
    () async {
      final port = await _scheduleServer(_syncHandler);
      final socket = await Socket.connect('localhost', port);

      try {
        socket.write('GET / HTTP/01.01\r\n');
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
    'a request with whitespace in HTTP version results in a 400 response',
    () async {
      final port = await _scheduleServer(_syncHandler);
      final socket = await Socket.connect('localhost', port);

      try {
        socket.write('GET / HTTP/ 1.1\r\n');
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
    'a request with HTTP/1.2 version is accepted as HTTP/1.x compatible',
    () async {
      final port = await _scheduleServer(_syncHandler);
      final socket = await Socket.connect('localhost', port);

      try {
        socket.write('GET / HTTP/1.2\r\n');
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

  test(
    'a request with userinfo in Host header results in a 400 response',
    () async {
      final port = await _scheduleServer(_syncHandler);
      final socket = await Socket.connect('localhost', port);

      try {
        socket.write('GET / HTTP/1.1\r\n');
        socket.write('Host: user@localhost\r\n');
        socket.write('Connection: close\r\n');
        socket.write('\r\n');
      } finally {
        await socket.close();
      }

      expect(await utf8.decodeStream(socket), isABadRequestResponse);
    },
  );

  test(
    'a request with path in Host header results in a 400 response',
    () async {
      final port = await _scheduleServer(_syncHandler);
      final socket = await Socket.connect('localhost', port);

      try {
        socket.write('GET / HTTP/1.1\r\n');
        socket.write('Host: localhost/path\r\n');
        socket.write('Connection: close\r\n');
        socket.write('\r\n');
      } finally {
        await socket.close();
      }

      expect(await utf8.decodeStream(socket), isABadRequestResponse);
    },
  );

  test(
    'a request with incomplete body (undersend) results in connection close',
    () async {
      final port = await _scheduleServer((request) async {
        await request.readAsString();
        return Response.ok('Hello');
      });
      final socket = await Socket.connect('localhost', port);

      try {
        socket.write('POST / HTTP/1.1\r\n');
        socket.write('Host: localhost\r\n');
        socket.write('Content-Length: 10\r\n');
        socket.write('Connection: close\r\n');
        socket.write('\r\n');
        socket.write('hello');
      } finally {
        await socket.close();
      }

      final response = await utf8.decodeStream(socket);
      expect(response, isNot(contains('200 OK')));
    },
  );

  test(
    'a request with non-ASCII character in URL results in a 400 response',
    () async {
      final port = await _scheduleServer(_syncHandler);
      final socket = await Socket.connect('localhost', port);

      try {
        socket.write('GET /foo');
        socket.add([255]); // Non-ASCII byte!
        socket.write(' HTTP/1.1\r\n');
        socket.write('Host: localhost\r\n');
        socket.write('Connection: close\r\n');
        socket.write('\r\n');
      } finally {
        await socket.close();
      }

      expect(await utf8.decodeStream(socket), isABadRequestResponse);
    },
  );

  test('a CONNECT request results in a 405 response', () async {
    final port = await _scheduleServer(_syncHandler);
    final socket = await Socket.connect('localhost', port);

    try {
      socket.write('CONNECT example.com:443 HTTP/1.1\r\n');
      socket.write('Host: example.com:443\r\n');
      socket.write('Connection: close\r\n');
      socket.write('\r\n');
    } finally {
      await socket.close();
    }

    expect(await utf8.decodeStream(socket), contains('405 Method Not Allowed'));
  });

  test('a TRACE request results in a 405 response', () async {
    final port = await _scheduleServer(_syncHandler);
    final socket = await Socket.connect('localhost', port);

    try {
      socket.write('TRACE / HTTP/1.1\r\n');
      socket.write('Host: localhost\r\n');
      socket.write('Connection: close\r\n');
      socket.write('\r\n');
    } finally {
      await socket.close();
    }

    expect(await utf8.decodeStream(socket), contains('405 Method Not Allowed'));
  });

  test('a request with empty Host header results in a 400 response', () async {
    final port = await _scheduleServer(_syncHandler);
    final socket = await Socket.connect('localhost', port);

    try {
      socket.write('GET / HTTP/1.1\r\n');
      socket.write('Host: \r\n');
      socket.write('Connection: close\r\n');
      socket.write('\r\n');
    } finally {
      await socket.close();
    }

    expect(await utf8.decodeStream(socket), isABadRequestResponse);
  });

  test('a request with too long URL results in a 414 response', () async {
    final port = await _scheduleServer(_syncHandler);
    final socket = await Socket.connect('localhost', port);

    try {
      socket.write('GET /');
      socket.write('a' * ($Limit.maxUrlSize + 1));
      socket.write(' HTTP/1.1\r\n');
      socket.write('Host: localhost\r\n');
      socket.write('Connection: close\r\n');
      socket.write('\r\n');
    } finally {
      await socket.close();
    }

    final response = await utf8.decodeStream(socket);
    expect(response, contains('414 URI Too Long'));
  });

  test('a request with incomplete chunked body results in error', () async {
    final port = await _scheduleServer((request) async {
      try {
        await request.readAsString();
      } catch (e) {
        return Response.ok('Error caught');
      }
      return Response.ok('No error');
    });
    final socket = await Socket.connect('localhost', port);

    try {
      socket.write('POST / HTTP/1.1\r\n');
      socket.write('Host: localhost\r\n');
      socket.write('Transfer-Encoding: chunked\r\n');
      socket.write('\r\n');
      socket.write('5\r\nhello\r\n'); // No zero terminator!
      await socket.flush();
    } finally {
      await socket.close();
    }

    final response = await utf8.decodeStream(socket);
    expect(response, contains('Error caught'));
  });

  test('a request with too large headers results in a 431 response', () async {
    final port = await _scheduleServer(_syncHandler);
    final socket = await Socket.connect('localhost', port);

    try {
      socket.write('GET / HTTP/1.1\r\n');
      socket.write('Host: localhost\r\n');
      socket.write('Large-Header: ');
      socket.write('a' * ($Limit.maxHeaderSize + 1));
      socket.write('\r\n');
      socket.write('Connection: close\r\n');
      socket.write('\r\n');
    } finally {
      await socket.close();
    }

    final response = await utf8.decodeStream(socket);
    expect(response, contains('431 Request Header Fields Too Large'));
  });

  test('HEAD response must not contain a message body (chunked)', () async {
    final port = await _scheduleServer(
      (request) => Response.ok(Stream.fromIterable(['Hello'.codeUnits])),
    );
    final socket = await Socket.connect('localhost', port);

    try {
      socket.write('HEAD / HTTP/1.1\r\n');
      socket.write('Host: localhost\r\n');
      socket.write('Connection: close\r\n');
      socket.write('\r\n');
    } finally {
      await socket.close();
    }

    final response = await utf8.decodeStream(socket);
    expect(response, contains('200 OK'));
    expect(response, isNot(contains('Hello')));
    expect(response, isNot(contains('0\r\n\r\n')));
  });

  test(
    'COMP-POST-CL-UNDERSEND',
    skip: 'Fails in checker: COMP-POST-CL-UNDERSEND',
    () async {
      final port = await _scheduleServer((request) async {
        try {
          await request.readAsString();
        } catch (e) {
          return Response.ok('Error caught');
        }
        return Response.ok('No error');
      });
      final socket = await Socket.connect('localhost', port);
      addTearDown(socket.close);

      socket.write('POST / HTTP/1.1\r\n');
      socket.write('Host: localhost\r\n');
      socket.write('Content-Length: 10\r\n');
      socket.write('\r\n');
      socket.write('hello'); // Only 5 bytes!
      await socket.flush();

      final response = await utf8.decodeStream(socket);
      expect(response, contains('Error caught'));
    },
  );
  test('SMUG-TE-NOT-FINAL-CHUNKED', () async {
    final port = await _scheduleServer(_syncHandler);
    final socket = await Socket.connect('localhost', port);
    addTearDown(socket.close);

    socket.write('POST / HTTP/1.1\r\n');
    socket.write('Host: localhost\r\n');
    socket.write('Transfer-Encoding: chunked, gzip\r\n');
    socket.write('\r\n');
    socket.write('0\r\n\r\n');

    final response = await utf8.decodeStream(socket);
    expect(response, contains('400 Bad Request'));
  });

  test('SMUG-CHUNK-BARE-SEMICOLON', () async {
    final port = await _scheduleServer(_syncHandler);
    final socket = await Socket.connect('localhost', port);
    addTearDown(socket.close);

    socket.write('POST / HTTP/1.1\r\n');
    socket.write('Host: localhost\r\n');
    socket.write('Transfer-Encoding: chunked\r\n');
    socket.write('\r\n');
    socket.write('5;\r\nhello\r\n0\r\n\r\n');

    final response = await utf8.decodeStream(socket);
    expect(response, contains('501 Not Implemented'));
  });

  test('SMUG-CHUNK-EXT-INVALID-TOKEN', () async {
    final port = await _scheduleServer(_syncHandler);
    final socket = await Socket.connect('localhost', port);
    addTearDown(socket.close);

    socket.write('POST / HTTP/1.1\r\n');
    socket.write('Host: localhost\r\n');
    socket.write('Transfer-Encoding: chunked\r\n');
    socket.write('\r\n');
    socket.write('5;bad[=x\r\nhello\r\n0\r\n\r\n');

    final response = await utf8.decodeStream(socket);
    expect(response, contains('501 Not Implemented'));
  });

  test('SMUG-CHUNK-MISSING-TRAILING-CRLF', () async {
    final port = await _scheduleServer(_syncHandler);
    final socket = await Socket.connect('localhost', port);
    addTearDown(socket.close);

    socket.write('POST / HTTP/1.1\r\n');
    socket.write('Host: localhost\r\n');
    socket.write('Transfer-Encoding: chunked\r\n');
    socket.write('Connection: close\r\n');
    socket.write('\r\n');
    socket.write('5\r\nhello0\r\n\r\n');

    final response = await utf8.decodeStream(socket);
    expect(response, contains('400 Bad Request'));
  });

  test('SMUG-CHUNK-SPILL', () async {
    final port = await _scheduleServer(_syncHandler);
    final socket = await Socket.connect('localhost', port);
    addTearDown(socket.close);

    socket.write('POST / HTTP/1.1\r\n');
    socket.write('Host: localhost\r\n');
    socket.write('Transfer-Encoding: chunked\r\n');
    socket.write('\r\n');
    socket.write('5\r\nhello!!\r\n0\r\n\r\n');

    final response = await utf8.decodeStream(socket);
    expect(response, contains('400 Bad Request'));
  });

  test('SMUG-CHUNK-EXT-CTRL', () async {
    final port = await _scheduleServer(_syncHandler);
    final socket = await Socket.connect('localhost', port);
    addTearDown(socket.close);

    socket.write('POST / HTTP/1.1\r\n');
    socket.write('Host: localhost\r\n');
    socket.write('Transfer-Encoding: chunked\r\n');
    socket.write('\r\n');
    socket.write('5;\x00ext\r\nhello\r\n0\r\n\r\n');

    final response = await utf8.decodeStream(socket);
    expect(response, contains('501 Not Implemented'));
  });

  test('SMUG-CHUNK-EXT-CR', () async {
    final port = await _scheduleServer(_syncHandler);
    final socket = await Socket.connect('localhost', port);
    addTearDown(socket.close);

    socket.write('POST / HTTP/1.1\r\n');
    socket.write('Host: localhost\r\n');
    socket.write('Transfer-Encoding: chunked\r\n');
    socket.write('\r\n');
    socket.write('5;a\rX\r\nhello\r\n0\r\n\r\n');

    final response = await utf8.decodeStream(socket);
    expect(response, contains('501 Not Implemented'));
  });
  test('MAL-POST-CL-HUGE-NO-BODY', () async {
    final port = await _scheduleServer(_syncHandler);
    final socket = await Socket.connect('localhost', port);
    addTearDown(socket.close);

    socket.write('POST / HTTP/1.1\r\n');
    socket.write('Host: localhost\r\n');
    socket.write('Content-Length: 999999999\r\n');
    socket.write('\r\n');
    await socket.flush();

    final response = await utf8.decodeStream(socket);
    expect(response, contains('413 Content Too Large'));
  });

  test('COOK-ECHO', () async {
    final port = await _scheduleServer((request) {
      if (request.url.path == 'echo') {
        final sb = StringBuffer();
        sb.writeln('${request.method} ${request.requestedUri.path} HTTP/1.1');
        request.headers.forEach((key, value) {
          sb.writeln('$key: $value');
        });
        sb.writeln();
        return Response.ok(sb.toString());
      }
      return Response.ok('sync');
    });
    final socket = await Socket.connect('localhost', port);
    addTearDown(socket.close);

    socket.write('GET /echo HTTP/1.1\r\n');
    socket.write('Host: localhost\r\n');
    socket.write('Cookie: foo=bar\r\n');
    socket.write('Connection: close\r\n');
    socket.write('\r\n');

    final response = await utf8.decodeStream(socket);
    expect(response, contains('Cookie: foo=bar'));
  });

  test('COOK-PARSED-BASIC', () async {
    final port = await _scheduleServer((request) {
      if (request.url.path == 'cookie') {
        final cookieHeader = request.headers['cookie'];
        if (cookieHeader == null) return Response.ok('No cookies');
        final cookies = cookieHeader.split(';').map((e) => e.trim()).toList();
        final sb = StringBuffer();
        for (var cookie in cookies) {
          sb.writeln(cookie);
        }
        return Response.ok(sb.toString());
      }
      return Response.ok('sync');
    });
    final socket = await Socket.connect('localhost', port);
    addTearDown(socket.close);

    socket.write('GET /cookie HTTP/1.1\r\n');
    socket.write('Host: localhost\r\n');
    socket.write('Cookie: foo=bar\r\n');
    socket.write('Connection: close\r\n');
    socket.write('\r\n');

    final response = await utf8.decodeStream(socket);
    expect(response, contains('foo=bar'));
  });

  test('COOK-PARSED-MULTI', () async {
    final port = await _scheduleServer((request) {
      if (request.url.path == 'cookie') {
        final cookieHeader = request.headers['cookie'];
        if (cookieHeader == null) return Response.ok('No cookies');
        final cookies = cookieHeader.split(';').map((e) => e.trim()).toList();
        final sb = StringBuffer();
        for (var cookie in cookies) {
          sb.writeln(cookie);
        }
        return Response.ok(sb.toString());
      }
      return Response.ok('sync');
    });
    final socket = await Socket.connect('localhost', port);
    addTearDown(socket.close);

    socket.write('GET /cookie HTTP/1.1\r\n');
    socket.write('Host: localhost\r\n');
    socket.write('Cookie: a=1; b=2; c=3\r\n');
    socket.write('Connection: close\r\n');
    socket.write('\r\n');

    final response = await utf8.decodeStream(socket);
    expect(response, contains('a=1'));
    expect(response, contains('b=2'));
    expect(response, contains('c=3'));
  });
}

Future<int> _scheduleServer(Handler handler) async {
  final server = await RawShelfServer.serve(handler, 'localhost', 0);
  addTearDown(server.close);
  return server.port;
}

Response _syncHandler(Request request) =>
    Response.ok('Hello from ${request.requestedUri.path}');
