// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

/// Parses a single hex character byte (0-9, a-f, A-F) to its integer value.
/// Returns `-1` if the byte is not a valid hex character.
@pragma('vm:prefer-inline')
int parseHex(int byte) {
  assert(byte >= 0 && byte <= 255);
  // This SEEMS like a lot of code, but it's branchless and in benchmarks it
  // is faster than a series of `if` checks by 13%
  final entry = _charFlags[byte];
  final isValidHex = (entry & 0x10) >> 4;
  final mask = isValidHex - 1;
  return (entry & 0x0F) | mask;
}

/// Returns `true` if the byte is a valid HTTP token character (tchar).
@pragma('vm:prefer-inline')
bool isTchar(int byte) {
  assert(byte >= 0 && byte <= 255);
  return (_charFlags[byte] & 0x20) != 0;
}

/// Returns `true` if the byte is an invalid character in a header value.
@pragma('vm:prefer-inline')
bool isInvalidHeaderValueChar(int byte) {
  assert(byte >= 0 && byte <= 255);
  return (_charFlags[byte] & 0x40) != 0;
}

/// Returns `true` if the byte is an invalid character in a URL.
@pragma('vm:prefer-inline')
bool isInvalidUrlChar(int byte) {
  assert(byte >= 0 && byte <= 255);
  return (_charFlags[byte] & 0x80) != 0;
}

/// A lookup table for character classification and parsing.
///
/// This table contains 256 entries, one for each possible byte value.
/// Each entry is a bit mask that encodes multiple properties of the character:
///
/// *   **Bits 0-3:** The numeric value of the hex digit (0-15), if applicable.
/// *   **Bit 4 (0x10):** Flag indicating the character is a valid hex digit
///     (0-9, a-f, A-F).
/// *   **Bit 5 (0x20):** Flag indicating the character is a valid HTTP token
///     character (tchar).
/// *   **Bit 6 (0x40):** Flag indicating the character is invalid in a header
///     value.
/// *   **Bit 7 (0x80):** Flag indicating the character is invalid in a URL.
///
/// This layout allows extremely fast checks in performance-critical parsing
/// loops by avoiding multiple conditional branches.
final Uint8List _charFlags = _generateFlags();

Uint8List _generateFlags() {
  final list = Uint8List(256);
  for (var i = 0; i < 256; i++) {
    var flags = 0;
    // isTchar
    if ((i >= 65 && i <= 90) ||
        (i >= 97 && i <= 122) ||
        (i >= 48 && i <= 57) ||
        [
          33,
          35,
          36,
          37,
          38,
          39,
          42,
          43,
          45,
          46,
          94,
          95,
          96,
          124,
          126,
        ].contains(i)) {
      flags |= 0x20;
    }
    // isHex
    if (i >= 48 && i <= 57) {
      flags |= 0x10 | (i - 48);
    } else if (i >= 97 && i <= 102) {
      flags |= 0x10 | (i - 97 + 10);
    } else if (i >= 65 && i <= 70) {
      flags |= 0x10 | (i - 65 + 10);
    }
    // isInvalidHeaderValueChar (Bit 6)
    if ((i < 32 && i != 9 && i != 13) || i == 127) {
      flags |= 0x40;
    }

    // isInvalidUrlChar (Bit 7)
    if (i == 0 || i == 10 || i == 13 || i > 127) {
      flags |= 0x80;
    }

    list[i] = flags;
  }
  return list;
}
