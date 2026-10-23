// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:io';

import 'package:_shelf_compliance/adapter_conformance.dart';
import 'package:bottom_shelf/bottom_shelf.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  testAll(
    _serve,
    defaultPoweredByHeader: 'Dart with package:bottom_shelf',
    supportsSecurityContext: false,
  );
}

Future<ConformanceServer> _serve(Handler handler, ServeOptions options) async {
  final server = options.overridesPoweredByHeader
      ? await RawShelfServer.serve(
          handler,
          'localhost',
          0,
          poweredBy: options.poweredByHeader,
        )
      : await RawShelfServer.serve(handler, 'localhost', 0);
  return _RawConformanceServer(server);
}

final class _RawConformanceServer implements ConformanceServer {
  final RawShelfServer _server;

  _RawConformanceServer(this._server);

  @override
  int get port => _server.port;

  @override
  InternetAddress get address => _server.address;

  @override
  Future<void> close() => _server.close();
}
