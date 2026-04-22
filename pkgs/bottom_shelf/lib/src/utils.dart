// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Parses a single hex character byte (0-9, a-f, A-F) to its integer value.
/// Returns a negative value if the byte is not a valid hex character.
@pragma('vm:prefer-inline')
int parseHex(int byte) {
  assert(byte >= 0 && byte <= 255);
  final entry = _charFlags.codeUnitAt(byte);
  return entry.toSigned(8);
}

/// Whether the byte is a valid HTTP token character (tchar).
@pragma('vm:prefer-inline')
bool isTchar(int byte) {
  assert(byte >= 0 && byte <= 255);
  return (_charFlags.codeUnitAt(byte) & _nonTChar) == 0;
}

/// Whether the byte is an invalid character in a header value.
@pragma('vm:prefer-inline')
bool isInvalidHeaderValueChar(int byte) {
  assert(byte >= 0 && byte <= 255);
  return (_charFlags.codeUnitAt(byte) & _nonHeaderChar) != 0;
}

/// Whether the byte is an invalid character in a URL.
@pragma('vm:prefer-inline')
bool isInvalidUrlChar(int byte) {
  assert(byte >= 0 && byte <= 255);
  return (_charFlags.codeUnitAt(byte) & _nonUrlChar) != 0;
}

// Bit masks for the bits in `_charFlags`.
// Chosen so that they are not set for a hex digit.
const _nonUrlChar = 0x10;
const _nonTChar = 0x20;
const _nonHeaderChar = 0x40;

/// A lookup table for character classification and parsing.
///
/// This table contains 256 entries, one for each byte value.
/// The bits of each entry encode multiple properties of the character:
///
/// *   **Bits 0-3:** The numeric value of the hex digit (0-15), if applicable.
/// *   **Bit 4 (0x10):** Flag indicating the character is invalid in a URL.
/// *   **Bit 5 (0x20):** Flag indicating the character is not a valid HTTP token
///     character (tchar).
/// *   **Bit 6 (0x40):** Flag indicating the character is invalid in a header
///     value.
/// *   **Bit 7 (0x80):** Flag indicating the character is not a valid hex digit
///     (0-9, a-f, A-F). The entry for all hex digits are their value,
///     and for all non-hex-digits, the entry is >= 0x80.
///
/// This layout allows extremely fast checks in performance-critical parsing
/// loops by avoiding multiple conditional branches.
const String _charFlags = 
  '\xf0\xe0\xe0\xe0\xe0\xe0\xe0\xe0\xe0\xa0\xf0\xe0\xe0\xb0\xe0\xe0'
  '\xe0\xe0\xe0\xe0\xe0\xe0\xe0\xe0\xe0\xe0\xe0\xe0\xe0\xe0\xe0\xe0'
  '\xa0\x80\xa0\x80\x80\x80\x80\x80\xa0\xa0\x80\x80\xa0\x80\x80\xa0'
  '\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\xa0\xa0\xa0\xa0\xa0\xa0'
  '\xa0\x0a\x0b\x0c\x0d\x0e\x0f\x80\x80\x80\x80\x80\x80\x80\x80\x80'
  '\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\xa0\xa0\xa0\x80\x80'
  '\x80\x0a\x0b\x0c\x0d\x0e\x0f\x80\x80\x80\x80\x80\x80\x80\x80\x80'
  '\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\xa0\x80\xa0\x80\xe0'
  '\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0'
  '\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0'
  '\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0'
  '\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0'
  '\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0'
  '\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0'
  '\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0'
  '\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0\xb0';

// The string above is a string representation of the bytes
// that the following function would create:
//
// const _nonHexDigit = 0x80; // Only bit whose placement matters.
// Uint8List _generateFlags() {
//   final list = Uint8List(256);
//   for (var i = 0; i < 256; i++) {
//     var flags = _nonTChar | _nonHexDigit;
//     // isTchar
//     if ((i >= 65 && i <= 90) ||
//         (i >= 97 && i <= 122) ||
//         (i >= 48 && i <= 57) ||
//         [
//           33,
//           35,
//           36,
//           37,
//           38,
//           39,
//           42,
//           43,
//           45,
//           46,
//           94,
//           95,
//           96,
//           124,
//           126,
//         ].contains(i)) {
//       flags &= ~_nonTChar;
//     }
//     // Hex digit (bits 0..3, and not 7)
//     if (i >= 0x30 && i <= 0x39) {
//       flags &= ~_nonHexDigit;
//       flags |= (i - 0x30);
//     } else if (i >= 0x41 && i <= 0x46 ||
//                i >= 0x61 && i <= 0x66) {
//       flags &= ~_nonHexDigit;
//       flags |= (i | 0x20) - 0x61 + 10;
//     }
//     // isInvalidUrlChar (Bit 5)
//     if (i == 0 || i == 10 || i == 13 || i > 127) {
//       flags |= _nonUrlChar;
//     }
//     // isInvalidHeaderValueChar (Bit 6)
//     if ((i < 32 && i != 9 && i != 13) || i == 127) {
//       flags |= _nonHeaderChar;
//     }
//     list[i] = flags;
//   }
//   return list;
// }
