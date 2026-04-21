// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Exception thrown when a request is malformed or violates protocol limits.
final class BadRequestException implements Exception {
  final String message;

  /// The original exception that caused this bad request, if any.
  final Object? innerException;

  /// The stack trace of the original exception, if any.
  final StackTrace? innerStack;

  const BadRequestException(
    this.message, {
    this.innerException,
    this.innerStack,
  });

  @override
  String toString() {
    final sb = StringBuffer('BadRequestException: $message');
    if (innerException != null) {
      sb.write('\nInner exception: $innerException');
    }
    return sb.toString();
  }
}
