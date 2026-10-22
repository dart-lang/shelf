// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:shelf/shelf.dart';

/// Starts a server on `localhost`, on an ephemeral port, that dispatches
/// requests to [handler].
typedef ServeCallback =
    Future<ConformanceServer> Function(Handler handler, ServeOptions options);

/// A running server started by a [ServeCallback].
abstract interface class ConformanceServer {
  /// The port the server is listening on.
  int get port;

  /// The address the server is listening on.
  InternetAddress get address;

  /// Stops the server, closing any active connections.
  Future<void> close();
}

/// Server-level options a [ServeCallback] must honor.
final class ServeOptions {
  /// If not `null`, the server must serve HTTPS using this context.
  final SecurityContext? securityContext;

  /// Whether to replace the adapter's default `X-Powered-By` header with
  /// [poweredByHeader].
  final bool overridesPoweredByHeader;

  /// The `X-Powered-By` header to send, or `null` to omit it.
  ///
  /// Only used if [overridesPoweredByHeader] is `true`.
  final String? poweredByHeader;

  /// Options that use the adapter's default `X-Powered-By` header.
  const ServeOptions({this.securityContext})
    : overridesPoweredByHeader = false,
      poweredByHeader = null;

  /// Options that replace the adapter's default `X-Powered-By` header.
  ///
  /// If [poweredByHeader] is `null`, the header is omitted.
  const ServeOptions.poweredBy(this.poweredByHeader, {this.securityContext})
    : overridesPoweredByHeader = true;
}
