// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:bottom_shelf/src/utils.dart';
import 'package:test/test.dart';

void main() {
  group('parseHex', () {
    test('parses 0-9', () {
      for (var i = 0; i <= 9; i++) {
        expect(parseHex(48 + i), i); // '0' is 48
      }
    });

    test('parses a-f', () {
      for (var i = 0; i < 6; i++) {
        expect(parseHex(97 + i), 10 + i); // 'a' is 97
      }
    });

    test('parses A-F', () {
      for (var i = 0; i < 6; i++) {
        expect(parseHex(65 + i), 10 + i); // 'A' is 65
      }
    });

    test('returns -1 for invalid characters', () {
      expect(parseHex(47), -1); // '/'
      expect(parseHex(58), -1); // ':'
      expect(parseHex(96), -1); // '`'
      expect(parseHex(103), -1); // 'g'
      expect(parseHex(64), -1); // '@'
      expect(parseHex(71), -1); // 'G'
      expect(parseHex(32), -1); // space
    });
  });
}
