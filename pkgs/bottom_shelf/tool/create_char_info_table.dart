#!/usr/bin/env dart
// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

/// Builds the string literal used as table by `lib/src/util.dart`.

void main() {
  final bytes = _generateFlags();
  print(
    template(bytes, [
      (
        name: 'nonUrlChar',
        bit: _nonUrlCharBit,
        doc: 'invalid in a URL.',
        declare: true,
      ),
      (
        name: 'nonTChar',
        bit: _nonTCharBit,
        doc: 'not a valid HTTP token character (tChar).',
        declare: true,
      ),
      (
        name: 'nonHeaderChar',
        bit: _nonHeaderCharBit,
        doc: 'not a valid in an HTTP header value.',
        declare: true,
      ),
      (
        name: 'nonHexDigit',
        bit: _nonHexDigitBit,
        doc: 'not a hex digit a URL.',
        declare: false,
      ),
    ]),
  );
}

String template(
  Uint8List bytes,
  List<({String name, int bit, String doc, bool declare})> flags,
) {
  final buffer = StringBuffer();
  buffer
    ..writeln('// Bit masks for the bits in `_charFlags`.')
    ..writeln('// Chosen so that they are not set for a hex digit.')
    ..writeln();

  // Sort by bit-position.
  flags.sort((a, b) => a.bit.compareTo(b.bit));

  for (final (:name, :bit, :doc, :declare) in flags) {
    if (declare) {
      buffer
        ..writeln('/// Bit set when the character is $doc')
        ..writeln('const int _$name = 0x${(1 << bit).toRadixString(16)};')
        ..writeln();
    }
  }
  buffer.write('''
/// A lookup table for character classification and parsing.
///
/// This table contains 256 entries, one for each byte value.
/// The bits of each entry encode multiple properties of the character:
///
/// *   **Bits 0-3:** The numeric value of the hex digit (0-15), if applicable.
''');
  for (var (name: _, :bit, :doc, declare: _) in flags) {
    final lineStart = buffer.length;
    final hex = (1 << bit).toRadixString(16);
    buffer.write(
      '/// *   **Bit $bit (0x$hex):** Flag set if the character is ',
    );
    var lineCapacity = (lineStart + 80) - buffer.length;
    while (doc.length > lineCapacity) {
      final (firstLine, rest) = _splitLine(doc, lineCapacity);
      buffer.writeln(firstLine);
      buffer.write('///     ');
      lineCapacity = 80 - '///     '.length;
      doc = rest;
    }
    buffer.writeln(doc);
  }
  buffer.write('''
///
/// This layout allows extremely fast checks in performance-critical parsing
/// loops by avoiding multiple conditional branches.
''');
  buffer.write('const String _charFlags =');
  var i = 0;
  assert(bytes.length & 16 == 0);
  while (i < bytes.length) {
    buffer.write('\n    \'');
    var whitespace = false;
    var hasWhitespace = false;
    for (var col = 0; col < 16; col++) {
      final byte = bytes[i++];
      const hexDigits = '0123456789ABCDEF';
      buffer
        ..write(r'\x')
        ..write(hexDigits[byte >> 4])
        ..write(hexDigits[byte & 0xF]);
      whitespace = _isWhitespace(byte);
      hasWhitespace |= whitespace;
    }
    buffer.write('\'');
    hasWhitespace |= whitespace;
    if (i < bytes.length) {
      // Not last line.
      if (hasWhitespace && !whitespace) {
        // Has whitespace, but doesn't end with one. Would trigger lint.
        buffer.write(' // ignore: missing_whitespace_between_adjacent_strings');
      }
    }
  }
  buffer.write(';');

  return buffer.toString();
}

(String, String) _splitLine(String text, int lineCapacity) {
  assert(text.length > lineCapacity);
  // Split around last space before capacity. Omit the space.
  if (text.lastIndexOf(' ', lineCapacity + 1) case >= 0 && final split) {
    return (text.substring(0, split), text.substring(split + 1));
  }
  // No space found. Split after first `-` before capacity.
  if (text.lastIndexOf('-', lineCapacity) case >= 0 && final split) {
    return (text.substring(0, split + 1), text.substring(split + 1));
  }
  // No space or `-` found, just insert `-`. (Won't happen here.)
  return (
    text.replaceRange(lineCapacity - 1, text.length, '-'),
    text.substring(lineCapacity - 1),
  );
}

// Bit masks for the bits in `_charFlags`.
// Chosen so that they are not set for a hex digit.
const _nonUrlCharBit = 4;
const _nonUrlChar = 1 << _nonUrlCharBit;
const _nonTCharBit = 5;
const _nonTChar = 1 << _nonTCharBit;
const _nonHeaderCharBit = 6;
const _nonHeaderChar = 1 << _nonHeaderCharBit;
const _nonHexDigitBit = 7;
const _nonHexDigit = 1 << _nonHexDigitBit;

/// The value of [char] as a radix digit.
///
/// Is valid if value is less than the target radix.
int _asRadixDigit(int char) {
  if (char ^ 0x30 case < 10 && final digit) return digit;
  // Lower case letters, move characters around so letters become 0..26,
  // and all others are larger. Then add 10 to get the radix value,
  // or something larger.
  return (((char | 0x20) + (0x80 - 0x61)) ^ 0x80) + 10;
}

/// Is a TAB, CR, LF or space.
///
/// This is the whitespace recognized by the
/// `missing_whitespace_between_adjacent_strings` lint.
bool _isWhitespace(int char) => '\t\n\r '.codeUnits.contains(char);
bool _isAsciiDigit(int char) => char ^ 0x30 <= 9;
bool _isAsciiLetter(int char) => (char |= 0x20) >= 0x61 && char <= 0x7A;

Uint8List _generateFlags() {
  final list = Uint8List(256);
  for (var i = 0; i < 256; i++) {
    var flags = 0;
    // Is not valid HTTP header token caracter (`_nonTChar`).
    // Valid tChars are digits, letters and any of ``!#$%&'*+-.^_`|~``.
    if (!_isAsciiDigit(i) &&
        !_isAsciiLetter(i) &&
        !r"!#$%&'*+-.^_`|~".codeUnits.contains(i)) {
      flags |= _nonTChar;
    }
    // isInvalidUrlChar (`_nonUrlChar`).
    // Valid characters is ASCII chars other than NUL, LF, CR and DEL
    if (i == 0 || i == 10 || i == 13 || i > 127) {
      flags |= _nonUrlChar;
    }
    // Is not valid header character (`_nonHeaderChar`).
    // Valid characters are any non-control ASCII character,
    // plus TAB tab and CR.
    if ((i < 32 && i != 9 && i != 13) || i == 127) {
      flags |= _nonHeaderChar;
    }
    // Hex digit or not (either bits 0..3 or `_nonHexDigit`).
    if (_asRadixDigit(i) case <= 15 && final hexValue) {
      assert(flags == 0);
      flags |= hexValue;
    } else {
      flags |= _nonHexDigit;
    }
    list[i] = flags;
  }
  return list;
}
