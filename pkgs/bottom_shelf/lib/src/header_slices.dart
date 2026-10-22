// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

/// Tracks whether the parser buffer backing a batch of [HeaderByteSlice]s is
/// still valid to read.
///
/// The parser reuses a single buffer across keep-alive requests. Once a
/// request's response has been written the buffer may be overwritten by the
/// next request, so slices from the previous request must not be read. This
/// token is invalidated at that point; reading a slice afterwards throws
/// instead of silently returning another request's bytes.
final class SliceBufferToken {
  bool _valid = true;

  bool get isValid => _valid;

  void invalidate() => _valid = false;
}

/// A slice of bytes representing a header key or value.
final class HeaderByteSlice {
  final Uint8List _buffer;
  final int _start;
  final int _end;
  final SliceBufferToken _token;

  HeaderByteSlice(this._buffer, this._start, this._end, this._token);

  int get length => _end - _start;

  void _checkValid() {
    if (!_token.isValid) {
      throw StateError(
        'This header can no longer be read: the request it belongs to has '
        'been fully processed and its backing buffer reused. Read (or copy) '
        'request headers before the handler returns its response.',
      );
    }
  }

  String asString() {
    _checkValid();
    return String.fromCharCodes(_buffer, _start, _end);
  }

  /// Parses `Content-Length` directly from slice bytes without allocating a
  /// [String]. Returns `null` if empty, contains non-digits, has leading zeros
  /// on a multi-digit value (`00`, `05`, `0200`), or overflows a 64-bit
  /// integer.
  int? parseContentLength() {
    _checkValid();
    final len = _end - _start;
    if (len == 0) return null;
    if (len > 1 && _buffer[_start] == 0x30) return null;
    var value = 0;
    for (var i = _start; i < _end; i++) {
      final digit = _buffer[i] - 0x30;
      if (digit < 0 || digit > 9) return null;
      if (value > 922337203685477580 ||
          (value == 922337203685477580 && digit > 7)) {
        return null;
      }
      value = value * 10 + digit;
    }
    return value;
  }

  /// Scans comma-separated tokens in a `Connection` header value
  /// (RFC 9110 §7.6.1, case-insensitive, OWS-trimmed).
  ///
  /// Returns `2` for `close` (which always overrides `keep-alive`), `1` for
  /// `keep-alive`, or [currentToken] if neither is present.
  int scanConnectionToken(int currentToken) {
    _checkValid();
    if (currentToken == 2) return 2;
    var result = currentToken;
    var pos = _start;
    while (pos <= _end) {
      var comma = pos;
      while (comma < _end && _buffer[comma] != 0x2C) {
        comma++;
      }
      var s = pos;
      var e = comma;
      while (s < e && (_buffer[s] == 0x20 || _buffer[s] == 0x09)) {
        s++;
      }
      while (e > s && (_buffer[e - 1] == 0x20 || _buffer[e - 1] == 0x09)) {
        e--;
      }
      final tokenLen = e - s;
      if (tokenLen == 5 && _matchesRange(s, 'close')) {
        return 2;
      } else if (tokenLen == 10 && _matchesRange(s, 'keep-alive')) {
        result = 1;
      }
      pos = comma + 1;
    }
    return result;
  }

  /// Checks whether any comma-separated OWS-trimmed token in this slice
  /// matches [lowerCaseToken] case-insensitively without allocating a [String].
  bool containsTokenIgnoreCase(String lowerCaseToken) {
    _checkValid();
    final targetLen = lowerCaseToken.length;
    var pos = _start;
    while (pos <= _end) {
      var comma = pos;
      while (comma < _end && _buffer[comma] != 0x2C) {
        comma++;
      }
      var s = pos;
      var e = comma;
      while (s < e && (_buffer[s] == 0x20 || _buffer[s] == 0x09)) {
        s++;
      }
      while (e > s && (_buffer[e - 1] == 0x20 || _buffer[e - 1] == 0x09)) {
        e--;
      }
      if (e - s == targetLen && _matchesRange(s, lowerCaseToken)) {
        return true;
      }
      pos = comma + 1;
    }
    return false;
  }

  bool _matchesRange(int start, String lowerCaseTarget) {
    for (var i = 0; i < lowerCaseTarget.length; i++) {
      var byte = _buffer[start + i];
      if (byte >= 65 && byte <= 90) byte += 32;
      if (byte != lowerCaseTarget.codeUnitAt(i)) return false;
    }
    return true;
  }

  /// Efficiently checks if the slice matches a lowercase ASCII string.
  bool matches(String lowerCaseTarget) {
    _checkValid();
    if (length != lowerCaseTarget.length) return false;
    return _matchesRange(_start, lowerCaseTarget);
  }

  /// Checks if the slice matches an ASCII string, case-insensitively.
  bool matchesKey(String target) {
    _checkValid();
    if (length != target.length) return false;
    for (var i = 0; i < length; i++) {
      var byte = _buffer[_start + i];
      if (byte >= 65 && byte <= 90) byte += 32;
      var targetByte = target.codeUnitAt(i);
      if (targetByte >= 65 && targetByte <= 90) targetByte += 32;
      if (byte != targetByte) return false;
    }
    return true;
  }
}

/// A pair of key/value slices.
final class HeaderEntrySlices {
  final HeaderByteSlice key;
  final HeaderByteSlice value;

  HeaderEntrySlices(this.key, this.value);
}
