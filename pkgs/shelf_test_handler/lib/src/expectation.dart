// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:shelf/shelf.dart';

import 'handler.dart';

/// A single expectation for an HTTP request sent to a [ShelfTestHandler].
class Expectation {
  /// The expected request method, or `null` if this allows any requests.
  final String? method;

  /// The expected request path, or `null` if this allows any requests.
  final String? path;

  /// The handler to use for requests that match this expectation.
  final Handler handler;

  Expectation(this.method, this.path, this.handler);

  /// Creates an expectation that allows any method and path.
  Expectation.anything(this.handler)
      : method = null,
        path = null;
}
