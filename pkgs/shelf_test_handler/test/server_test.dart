// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf_test_handler/shelf_test_handler.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  test('serves a ShelfTestHandler', () async {
    var server = await ShelfTestServer.create();
    addTearDown(server.close);

    server.handler.expect('GET', '/', expectAsync1((_) => Response.ok('')));
    var response = await http.get(server.url);
    expect(response.statusCode, equals(200));
  });

  test('supports request hijacking', () async {
    var server = await ShelfTestServer.create();
    addTearDown(server.close);

    server.handler.expect('GET', '/',
        webSocketHandler((WebSocketChannel webSocket, _) {
      webSocket.sink.add('hello!');
      webSocket.sink.close();
    }));

    var webSocket =
        await WebSocket.connect('ws://localhost:${server.url.port}');
    expect(webSocket, emits('hello!'));
  });
}
