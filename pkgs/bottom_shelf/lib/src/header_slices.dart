// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

/// A slice of bytes representing a header key or value.
class HeaderByteSlice {
  final Uint8List buffer;
  final int start;
  final int end;

  HeaderByteSlice(this.buffer, this.start, this.end);

  int get length => end - start;

  String asString() => String.fromCharCodes(buffer, start, end).trim();

  /// Efficiently checks if the slice matches a lowercase ASCII string.
  bool matches(String lowerCaseTarget) {
    if (length != lowerCaseTarget.length) return false;
    for (var i = 0; i < length; i++) {
      var byte = buffer[start + i];
      // Convert to lowercase if it's uppercase
      if (byte >= 65 && byte <= 90) byte += 32;
      if (byte != lowerCaseTarget.codeUnitAt(i)) return false;
    }
    return true;
  }
}

/// A pair of key/value slices.
class HeaderEntrySlices {
  final HeaderByteSlice key;
  final HeaderByteSlice value;

  HeaderEntrySlices(this.key, this.value);
}
