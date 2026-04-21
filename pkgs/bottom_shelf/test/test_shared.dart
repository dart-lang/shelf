// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

/// A custom matcher that verifies a string response is a 400 Bad Request.
final Matcher isABadRequestResponse = isA<String>().having(
  (s) => s,
  'is 400 Bad Request',
  startsWith('HTTP/1.1 400 Bad Request'),
);
