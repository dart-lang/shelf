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
