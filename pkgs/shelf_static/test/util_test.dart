// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:shelf_static/src/util.dart';
import 'package:test/test.dart';

void main() {
  test('toSecondResolution truncates milliseconds and microseconds', () {
    final dt = DateTime.utc(2024, 1, 2, 3, 4, 5, 678, 901);
    expect(toSecondResolution(dt), DateTime.utc(2024, 1, 2, 3, 4, 5));

    final wholeSecond = DateTime.utc(2024, 1, 2, 3, 4, 5);
    expect(toSecondResolution(wholeSecond), same(wholeSecond));
  });
}
