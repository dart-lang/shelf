// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';

import 'http_connection.dart';
import 'server_config.dart';

/// A high-performance Shelf server that uses raw [ServerSocket]s.
final class RawShelfServer extends ServerConfig {
  RawShelfServer._(
    super.handler,
    super.serverSocket,
    super.headerTimeout,
    super.bodyTimeout,
    super.onConnectionError,
    super.onAsyncError,
    super.automaticHeadMethodSupport,
  );

  int get port => serverSocket.port;
  InternetAddress get address => serverSocket.address;

  static Future<RawShelfServer> serve(
    Handler handler,
    Object address,
    int port, {
    int backlog = 0,
    bool shared = false,
    Duration? headerTimeout,
    Duration? bodyTimeout = const Duration(minutes: 1),
    ConnectionErrorCallback? onConnectionError,
    AsyncErrorCallback? onAsyncError,
    bool automaticHeadMethodSupport = true,
  }) async {
    final serverSocket = await ServerSocket.bind(
      address,
      port,
      backlog: backlog,
      shared: shared,
    );
    final server = RawShelfServer._(
      handler,
      serverSocket,
      headerTimeout,
      bodyTimeout,
      onConnectionError,
      onAsyncError,
      automaticHeadMethodSupport,
    );
    serverSocket.listen(server._handleConnection);
    return server;
  }

  void _handleConnection(Socket socket) {
    handleHttpConnection(
      socket: socket,
      config: this,
    );
  }

  Future<void> close() => serverSocket.close();
}
