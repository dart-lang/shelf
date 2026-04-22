// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';

import 'exceptions.dart';
import 'http_connection.dart';

/// A high-performance Shelf server that uses raw [ServerSocket]s.
final class RawShelfServer {
  final Handler _handler;
  final ServerSocket _serverSocket;
  final Duration? _headerTimeout;
  final ConnectionErrorCallback? _onConnectionError;
  final ErrorAction? Function(Object error, StackTrace stackTrace)?
  _onAsyncError;
  final bool _automaticHeadMethodSupport;

  RawShelfServer._(
    this._handler,
    this._serverSocket,
    this._headerTimeout,
    this._onConnectionError,
    this._onAsyncError,
    this._automaticHeadMethodSupport,
  );

  int get port => _serverSocket.port;
  InternetAddress get address => _serverSocket.address;

  static Future<RawShelfServer> serve(
    Handler handler,
    Object address,
    int port, {
    int backlog = 0,
    bool shared = false,
    Duration? headerTimeout,
    ConnectionErrorCallback? onConnectionError,
    ErrorAction? Function(Object error, StackTrace stackTrace)? onAsyncError,
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
      handler: _handler,
      headerTimeout: _headerTimeout,
      onConnectionError: _onConnectionError,
      onAsyncError: _onAsyncError,
      automaticHeadMethodSupport: _automaticHeadMethodSupport,
    );
  }

  Future<void> close() => _serverSocket.close();
}
