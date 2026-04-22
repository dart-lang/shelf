// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

enum ErrorResponse {
  badRequest(400, 'Bad Request'),
  methodNotAllowed(405, 'Method Not Allowed'),
  uriTooLong(414, 'URI Too Long'),
  headerFieldsTooLarge(431, 'Request Header Fields Too Large'),
  internalServerError(500, 'Internal Server Error'),
  notImplemented(501, 'Not Implemented');

  final int code;
  final String phrase;

  const ErrorResponse(this.code, this.phrase);

  Uint8List get bytes =>
      ascii.encode('HTTP/1.1 $code $phrase\r\nConnection: close\r\n\r\n');
}

/// Exception thrown when a request is malformed or violates protocol limits.
final class BadRequestException implements Exception {
  final String message;
  final ErrorResponse errorResponse;

  /// The original exception that caused this bad request, if any.
  final Object? innerException;

  /// The stack trace of the original exception, if any.
  final StackTrace? innerStack;

  /// Constructor for custom messages. Always uses `400 Bad Request`.
  const BadRequestException(
    this.message, {
    this.innerException,
    this.innerStack,
  }) : errorResponse = ErrorResponse.badRequest;

  /// Constructor for specific error responses. Uses the phrase as the message.
  BadRequestException.fromResponse(
    ErrorResponse response, {
    this.innerException,
    this.innerStack,
  }) : message = response.phrase,
       errorResponse = response;

  @override
  String toString() {
    final sb = StringBuffer('BadRequestException: $message');
    if (innerException != null) {
      sb.write('\nInner exception: $innerException');
    }
    return sb.toString();
  }
}

/// Directives for handling out-of-band asynchronous errors.
enum ErrorAction {
  /// Ignore the error and attempt to keep the connection alive.
  ignore,

  /// Destroy the socket.
  /// This is also the default behavior if `onAsyncError` returns `null`.
  destroy,

  /// Crash the isolate by re-throwing the error to the parent zone.
  crash,
}
