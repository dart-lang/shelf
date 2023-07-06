// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'expectation.dart';

/// A [Handler] that handles requests as specified by [expect] and
/// [expectAnything].
class ShelfTestHandler {
  /// The description used in debugging output for this handler.
  final String description;

  /// Whether to log each request to [printOnFailure].
  final bool _log;

  /// The zone in which this handler was created.
  final Zone _zone;

  /// The queue of expected requests to this handler.
  final _expectations = Queue<Expectation>();

  /// Creates a new handler that handles requests using handlers provided by
  /// [expect] and [expectAnything].
  ///
  /// If [log] is `true` (the default), this prints all requests using
  /// [printOnFailure].
  ///
  /// The [description] is used in debugging output for this handler. It
  /// defaults to "ShelfTestHandler".
  ShelfTestHandler({bool log = true, String? description})
      : _log = log,
        description = description ?? 'ShelfTestHandler',
        _zone = Zone.current;

  /// Expects that a single HTTP request with the given [method] and [path] will
  /// be made to `this`.
  ///
  /// The [path] should be root-relative; that is, it shuld start with "/".
  ///
  /// When a matching request is made, [handler] is used to handle that request.
  ///
  /// If this and/or [expectAnything] are called multiple times, the requests
  /// are expected to occur in the same order.
  void expect(String method, String path, Handler handler) {
    _expectations.add(Expectation(method, path, handler));
  }

  /// Expects that a single HTTP request will be made to `this`.
  ///
  /// When a request is made, [handler] is used to handle that request.
  ///
  /// If this and/or [expect] are called multiple times, the requests are
  /// expected to occur in the same order.
  void expectAnything(Handler handler) {
    _expectations.add(Expectation.anything(handler));
  }

  /// The implementation of [Handler].
  FutureOr<Response> call(Request request) async {
    var requestInfo = '${request.method} /${request.url}';
    if (_log) printOnFailure('[$description] $requestInfo');

    try {
      if (_expectations.isEmpty) {
        throw TestFailure(
            '$description received unexpected request $requestInfo.');
      }

      var expectation = _expectations.removeFirst();
      if ((expectation.method != null &&
              expectation.method != request.method) ||
          (expectation.path != '/${request.url.path}' &&
              expectation.path != null)) {
        var message = '$description received unexpected request $requestInfo.';
        if (expectation.method != null) {
          message += '\nExpected ${expectation.method} ${expectation.path}.';
        }
        throw TestFailure(message);
      }

      return await expectation.handler(request);
    } on HijackException catch (_) {
      rethrow;
    } catch (error, stackTrace) {
      _zone.handleUncaughtError(error, stackTrace);
      // We can't return null here, the handler type doesn't allow it.
      return Response.internalServerError(body: '$error');
    }
  }
}
