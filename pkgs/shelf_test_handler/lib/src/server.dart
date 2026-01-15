// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:http_multi_server/http_multi_server.dart';
import 'package:shelf/shelf_io.dart';
import 'package:test/test.dart';

import 'handler.dart';

/// A shorthand for creating an HTTP server serving a [ShelfTestHandler].
///
/// This is constructed using [create], and expectations may be registered
/// through [handler].
class ShelfTestServer {
  /// The underlying HTTP server.
  final HttpServer _server;

  /// The handler on which expectations can be registered.
  final ShelfTestHandler handler;

  /// The URL of this server.
  Uri get url => Uri.parse('http://localhost:${_server.port}');

  /// Creates a server serving a [ShelfTestHandler].
  ///
  /// If [log] is `true` (the default), this prints all requests using
  /// [printOnFailure].
  ///
  /// The [description] is used in debugging output for this handler. It
  /// defaults to "ShelfTestHandler".
  static Future<ShelfTestServer> create(
      {bool log = true, String? description}) async {
    var server = await HttpMultiServer.loopback(0);
    var handler = ShelfTestHandler(log: log, description: description);
    serveRequests(server, handler.call);
    return ShelfTestServer._(server, handler);
  }

  ShelfTestServer._(this._server, this.handler);

  /// Closes the server.
  ///
  /// If [force] is `true`, all active connections will be closed immediately.
  Future<void> close({bool force = false}) => _server.close(force: force);
}
