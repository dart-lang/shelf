// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library shelf_static.util;

import 'dart:async';

import 'package:stack_trace/stack_trace.dart';

/// Like [Future.sync], but wraps the Future in [Chain.track] as well.
Future syncFuture(callback()) => Chain.track(new Future.sync(callback));

DateTime toSecondResolution(DateTime dt) {
  if (dt.millisecond == 0) return dt;
  return dt.subtract(new Duration(milliseconds: dt.millisecond));
}
