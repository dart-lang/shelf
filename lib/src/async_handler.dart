// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:async/async.dart';
import 'package:shelf/shelf.dart';

class AsyncHandler {
  final ResultFuture<Handler> _future;

  AsyncHandler(Future<Handler> future) : _future = new ResultFuture(future);

  FutureOr<Response> call(Request request) {
    if (_future.result == null) {
      return _future.then((handler) => handler(request));
    }

    if (_future.result.isError)
      return new Future.error(_future.result.asError.error);

    return _future.result.asValue.value(request);
  }
}
