// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:shelf/shelf.dart';
import 'exceptions.dart';

typedef ConnectionErrorCallback =
    void Function(
      String message,
      Object error,
      StackTrace stackTrace, {
      required InternetAddress remoteAddress,
      required int remotePort,
    });

typedef AsyncErrorCallback =
    ErrorAction? Function(Object error, StackTrace stackTrace);

class ServerConfig {
  final Handler handler;
  final ServerSocket serverSocket;
  final Duration? headerTimeout;
  final Duration? bodyTimeout;
  final int? maxAllowedContentLength;
  final ConnectionErrorCallback? onConnectionError;
  final AsyncErrorCallback? onAsyncError;
  final bool automaticHeadMethodSupport;

  ServerConfig(
    this.handler,
    this.serverSocket,
    this.headerTimeout,
    this.bodyTimeout,
    this.maxAllowedContentLength,
    this.onConnectionError,
    this.onAsyncError,
    this.automaticHeadMethodSupport,
  );
}
