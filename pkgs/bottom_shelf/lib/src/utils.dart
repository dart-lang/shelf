// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Parses a single hex character byte (0-9, a-f, A-F) to its integer value.
/// Returns -1 if the byte is not a valid hex character.
int parseHex(int byte) {
  // TODO(kevmoo): consider using a lookup table.

  if (byte >= 48 && byte <= 57) return byte - 48; // 0-9
  if (byte >= 97 && byte <= 102) return byte - 97 + 10; // a-f
  if (byte >= 65 && byte <= 70) return byte - 65 + 10; // A-F
  return -1;
}

/// Returns true if the byte is a valid HTTP token character (tchar).
bool isTchar(int byte) =>
    (byte >= 65 && byte <= 90) || // A-Z
    (byte >= 97 && byte <= 122) || // a-z
    (byte >= 48 && byte <= 57) || // 0-9
    byte == 33 || // !
    byte == 35 || // #
    byte == 36 || // $
    byte == 37 || // %
    byte == 38 || // &
    byte == 39 || // '
    byte == 42 || // *
    byte == 43 || // +
    byte == 45 || // -
    byte == 46 || // .
    byte == 94 || // ^
    byte == 95 || // _
    byte == 96 || // `
    byte == 124 || // |
    byte == 126; // ~
