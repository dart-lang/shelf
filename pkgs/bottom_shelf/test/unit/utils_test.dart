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

    test('returns negative for invalid characters', () {
      expect(parseHex(47), isNegative); // '/'
      expect(parseHex(58), isNegative); // ':'
      expect(parseHex(96), isNegative); // '`'
      expect(parseHex(103), isNegative); // 'g'
      expect(parseHex(64), isNegative); // '@'
      expect(parseHex(71), isNegative); // 'G'
      expect(parseHex(32), isNegative); // space
    });
  });

  group('isTchar', () {
    const validChars =
        "!#\$%&'*+-.^_`|~0123456789"
        'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        'abcdefghijklmnopqrstuvwxyz';

    test('covers all 256 byte values correctly', () {
      for (var i = 0; i < 256; i++) {
        final char = String.fromCharCode(i);
        final expected = validChars.contains(char);
        expect(isTchar(i), expected, reason: 'Failed for byte $i ($char)');
      }
    });

    test('throws assertion error for values outside 0-255', () {
      expect(() => isTchar(-1), throwsA(isA<AssertionError>()));
      expect(() => isTchar(256), throwsA(isA<AssertionError>()));
    });
  });
  group('isInvalidHeaderValueChar', () {
    test('covers all 256 byte values correctly', () {
      for (var i = 0; i < 256; i++) {
        final expected = (i < 32 && i != 9 && i != 13) || i == 127;
        expect(
          isInvalidHeaderValueChar(i),
          expected,
          reason: 'Failed for byte $i',
        );
      }
    });
  });

  group('isInvalidUrlChar', () {
    test('covers all 256 byte values correctly', () {
      for (var i = 0; i < 256; i++) {
        final expected = i == 0 || i == 10 || i == 13 || i > 127;
        expect(isInvalidUrlChar(i), expected, reason: 'Failed for byte $i');
      }
    });
  });
}
