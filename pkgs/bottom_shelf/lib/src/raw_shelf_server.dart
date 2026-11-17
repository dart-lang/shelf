// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';

import 'constants.dart';
import 'http_connection.dart';
import 'server_config.dart';

/// A high-performance Shelf server that uses raw [ServerSocket]s.
final class RawShelfServer {
  final ServerConfig _config;

  RawShelfServer._(this._config);

  int get port => _config.serverSocket.port;
  InternetAddress get address => _config.serverSocket.address;

  static Future<RawShelfServer> serve(
    Handler handler,
    Object address,
    int port, {
    int backlog = 0,
    bool shared = false,
    Duration? headerTimeout,
    Duration? bodyTimeout = const Duration(minutes: 1),
    int? maxAllowedContentLength = $Limit.maxContentLength,
    ConnectionErrorCallback? onConnectionError,
    AsyncErrorCallback? onAsyncError,
    bool automaticHeadMethodSupport = true,
    String? poweredBy = 'Dart with package:bottom_shelf',
  }) async {
    final serverSocket = await ServerSocket.bind(
      address,
      port,
      backlog: backlog,
      shared: shared,
    );
    final config = ServerConfig(
      handler,
      serverSocket,
      headerTimeout,
      bodyTimeout,
      maxAllowedContentLength,
      onConnectionError,
      onAsyncError,
      automaticHeadMethodSupport,
      poweredBy,
    );
    final server = RawShelfServer._(config);
    serverSocket.listen(
      server._handleConnection,
      onError: (Object e, StackTrace st) {
        config.onConnectionError?.call(
          'Error accepting connection',
          e,
          st,
          remoteAddress: InternetAddress.anyIPv4,
          remotePort: 0,
        );
      },
    );
    return server;
  }

  void _handleConnection(Socket socket) {
    InternetAddress? remoteAddress;
    int? remotePort;
    try {
      remoteAddress = socket.remoteAddress;
      remotePort = socket.remotePort;
      socket.setOption(SocketOption.tcpNoDelay, true);
      handleHttpConnection(socket: socket, config: _config);
    } catch (e, st) {
      _config.onConnectionError?.call(
        'Error handling connection accept',
        e,
        st,
        remoteAddress: remoteAddress ?? InternetAddress.anyIPv4,
        remotePort: remotePort ?? 0,
      );
      try {
        socket.destroy();
      } catch (_) {}
    }
  }

  Future<void> close() => _config.serverSocket.close();
}
