// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:_shelf_compliance/adapter_conformance.dart';
import 'package:async/async.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

void main() {
  group('adapter conformance', () {
    testAll(_serve, defaultPoweredByHeader: 'Dart with package:shelf');
  });

  tearDown(() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
  });

  test('respects the "shelf.io.buffer_output" context parameter', () async {
    var controller = StreamController<String>();
    await _scheduleServer((request) {
      controller.add('Hello, ');

      return Response.ok(
        utf8.encoder.bind(controller.stream),
        context: {'shelf.io.buffer_output': false},
      );
    });

    var request = http.Request('GET', Uri.http('localhost:$_serverPort', ''));

    var response = await request.send();
    var stream = StreamQueue(utf8.decoder.bind(response.stream));

    var data = await stream.next;
    expect(data, equals('Hello, '));
    controller.add('world!');

    data = await stream.next;
    expect(data, equals('world!'));
    await controller.close();
    expect(stream.hasNext, completion(isFalse));
  });

  test('throws StateError when connection info is first read after connection '
      'closes', () async {
    late HttpConnectionInfo capturedInfo;
    await _scheduleServer((request) {
      capturedInfo =
          request.context['shelf.io.connection_info'] as HttpConnectionInfo;
      return Response.ok(
        'ok',
        headers: {HttpHeaders.connectionHeader: 'close'},
      );
    });

    var response = await _get();
    expect(response.statusCode, HttpStatus.ok);

    expect(() => capturedInfo.remoteAddress, throwsStateError);
    expect(() => capturedInfo.remotePort, throwsStateError);
    expect(() => capturedInfo.localPort, throwsStateError);
  });
}

Future<ConformanceServer> _serve(Handler handler, ServeOptions options) async {
  final server = options.overridesPoweredByHeader
      ? await shelf_io.serve(
          handler,
          'localhost',
          0,
          securityContext: options.securityContext,
          poweredByHeader: options.poweredByHeader,
        )
      : await shelf_io.serve(
          handler,
          'localhost',
          0,
          securityContext: options.securityContext,
        );
  return _HttpConformanceServer(server);
}

final class _HttpConformanceServer implements ConformanceServer {
  final HttpServer _server;

  _HttpConformanceServer(this._server);

  @override
  int get port => _server.port;

  @override
  InternetAddress get address => _server.address;

  @override
  Future<void> close() => _server.close(force: true);
}

int get _serverPort => _server!.port;

HttpServer? _server;

Future<void> _scheduleServer(Handler handler) async {
  assert(_server == null);
  _server = await shelf_io.serve(handler, 'localhost', 0);
}

Future<http.Response> _get() async {
  final client = HttpClient();
  try {
    final rq = await client.getUrl(Uri.http('localhost:$_serverPort', ''));
    final rs = await rq.close();
    return await http.Response.fromStream(
      http.StreamedResponse(rs, rs.statusCode),
    );
  } finally {
    client.close(force: true);
  }
}
