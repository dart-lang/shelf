// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart';
import 'package:test/test.dart';

import 'test_util.dart';

void main() {
  var server;
  setUp(() async {
    // Travis only supports IPv4 while other test platforms only support IPv6
    var address = Platform.environment.containsKey('TRAVIS')
        ? InternetAddress.LOOPBACK_IP_V4
        : InternetAddress.LOOPBACK_IP_V6;
    server = await IOServer.bind(address, 0);
  });

  tearDown(() => server.close());

  test("serves HTTP requests with the mounted handler", () async {
    server.mount(syncHandler);
    expect(await http.read(server.url), equals('Hello from /'));
  });

  test("delays HTTP requests until a handler is mounted", () async {
    expect(http.read(server.url), completion(equals('Hello from /')));
    await new Future.delayed(Duration.ZERO);

    server.mount(asyncHandler);
  });

  test("disallows more than one handler from being mounted", () async {
    server.mount((_) {});
    expect(() => server.mount((_) {}), throwsStateError);
    expect(() => server.mount((_) {}), throwsStateError);
  });
}
