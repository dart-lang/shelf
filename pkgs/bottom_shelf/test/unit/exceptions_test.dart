// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:bottom_shelf/src/exceptions.dart';
import 'package:test/test.dart';

void main() {
  test('BadRequestException.toString formats message and innerException', () {
    const simple = BadRequestException('invalid header');
    expect(simple.toString(), 'BadRequestException: invalid header');

    const withInner = BadRequestException(
      'bad url',
      innerException: FormatException('bad scheme'),
    );
    expect(
      withInner.toString(),
      'BadRequestException: bad url\n'
      'Inner exception: FormatException: bad scheme',
    );
  });
}
