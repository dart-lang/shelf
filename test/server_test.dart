// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:shelf_test_handler/shelf_test_handler.dart';

void main() {
  test("serves a ShelfTestHandler", () async {
    var server = await ShelfTestServer.create();
    addTearDown(server.close);

    server.handler.expect("GET", "/", expectAsync1((_) => new Response.ok("")));
    var response = await http.get(server.url);
    expect(response.statusCode, equals(200));
  });
}
