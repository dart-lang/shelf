// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

import 'constants.dart';
import 'exceptions.dart';
import 'header_slices.dart';

/// A high-performance, minimal HTTP/1.1 parser that uses byte slices.
final class RawHttpParser {
  static const int _stateMethod = 0;
  static const int _stateUrl = 1;
  static const int _stateVersion = 2;
  static const int _stateHeaderKey = 3;
  static const int _stateHeaderValue = 4;
  static const int _stateEndOfHeaders = 5;

  int _state = _stateMethod;
  String? method;
  String? url;
  String? version;

  final headerSlices = <HeaderEntrySlices>[];

  /// Internal buffer to accumulate header bytes across chunks.
  final Uint8List _buffer = Uint8List(64 * 1024);
  int _bufferPos = 0;

  int _currentFieldStart = 0;
  HeaderByteSlice? _lastKeySlice;

  static const int _maxHeaderSize = 64 * 1024;
  static const int _maxFieldSize = 8 * 1024;
  static const int _maxUrlSize = 8 * 1024;

  int _totalHeadersReceived = 0;
  int _consumedInLastChunk = 0;
  int get consumedInLastChunk => _consumedInLastChunk;

  void reset() {
    _state = _stateMethod;
    method = null;
    url = null;
    version = null;
    headerSlices.clear();
    _bufferPos = 0;
    _currentFieldStart = 0;
    _lastKeySlice = null;
    _totalHeadersReceived = 0;
  }

  bool process(Uint8List data) {
    _consumedInLastChunk = 0;
    for (var i = 0; i < data.length; i++) {
      _consumedInLastChunk++;
      final byte = data[i];
      _totalHeadersReceived++;

      if (_totalHeadersReceived > _maxHeaderSize) {
        throw const BadRequestException('Header size limit exceeded');
      }

      if (_bufferPos >= _buffer.length) {
        throw const BadRequestException('Buffer overflow');
      }

      _buffer[_bufferPos++] = byte;

      if (_bufferPos >= 2 &&
          _buffer[_bufferPos - 2] == $Chars.cr &&
          byte != $Chars.lf) {
        throw const BadRequestException('CR must be followed by LF');
      }

      switch (_state) {
        case _stateMethod:
          if (byte == $Chars.sp) {
            method = _getMethod(
              Uint8List.sublistView(_buffer, 0, _bufferPos - 1),
            );
            _currentFieldStart = _bufferPos;
            _state = _stateUrl;
          } else {
            if (byte == 0 || byte == $Chars.lf || byte == $Chars.cr) {
              throw const BadRequestException('Invalid character in method');
            }
            if (_bufferPos - _currentFieldStart > _maxFieldSize) {
              throw const BadRequestException('Method too long');
            }
          }
        case _stateUrl:
          if (byte == $Chars.sp) {
            url = String.fromCharCodes(
              _buffer,
              _currentFieldStart,
              _bufferPos - 1,
            );
            _currentFieldStart = _bufferPos;
            _state = _stateVersion;
          } else {
            if (byte == 0 || byte == $Chars.lf || byte == $Chars.cr) {
              throw const BadRequestException('Invalid character in URL');
            }
            if (_bufferPos - _currentFieldStart > _maxUrlSize) {
              throw const BadRequestException('URL too long');
            }
          }
        case _stateVersion:
          if (byte == $Chars.lf) {
            if (_bufferPos < 2 || _buffer[_bufferPos - 2] != $Chars.cr) {
              throw const BadRequestException('Bare line feed not allowed');
            }
            final v = String.fromCharCodes(
              _buffer,
              _currentFieldStart,
              _bufferPos - 2,
            ).trim();
            version = v.startsWith('HTTP/') ? v.substring(5) : v;
            _currentFieldStart = _bufferPos;
            _state = _stateHeaderKey;
          } else {
            if (byte == 0) {
              throw const BadRequestException('Invalid character in version');
            }
            if (_bufferPos - _currentFieldStart > 64) {
              throw const BadRequestException('Version too long');
            }
          }
        case _stateHeaderKey:
          if (byte == $Chars.colon) {
            var start = _currentFieldStart;
            var end = _bufferPos - 1;
            while (start < end && _buffer[start] == $Chars.sp) {
              start++;
            }
            while (end > start && _buffer[end - 1] == $Chars.sp) {
              end--;
            }

            _lastKeySlice = HeaderByteSlice(_buffer, start, end);
            _currentFieldStart = _bufferPos;
            _state = _stateHeaderValue;
          } else if (byte == $Chars.lf) {
            if (_bufferPos < 2 || _buffer[_bufferPos - 2] != $Chars.cr) {
              throw const BadRequestException('Bare line feed not allowed');
            }
            final len = _bufferPos - _currentFieldStart;
            if (len == 2) {
              _state = _stateEndOfHeaders;
              return true;
            }
            _currentFieldStart = _bufferPos;
          } else if (byte == 0) {
            throw const BadRequestException('Invalid character in header key');
          }
        case _stateHeaderValue:
          if (byte == $Chars.lf) {
            if (_bufferPos < 2 || _buffer[_bufferPos - 2] != $Chars.cr) {
              throw const BadRequestException('Bare line feed not allowed');
            }
            var start = _currentFieldStart;
            final end = _bufferPos - 2; // Exclude CRLF
            while (start < end && _buffer[start] == $Chars.sp) {
              start++;
            }

            final valueSlice = HeaderByteSlice(_buffer, start, end);
            headerSlices.add(HeaderEntrySlices(_lastKeySlice!, valueSlice));
            _currentFieldStart = _bufferPos;
            _state = _stateHeaderKey;
          } else if (byte < 32 && byte != 9 && byte != 13 || byte == 127) {
            throw const BadRequestException(
              'Invalid character in header value',
            );
          }
      }
    }
    return false;
  }

  String _getMethod(Uint8List bytes) => switch (bytes) {
    [71, 69, 84] => 'GET',
    [80, 79, 83, 84] => 'POST',
    [80, 85, 84] => 'PUT',
    [68, 69, 76, 69, 84, 69] => 'DELETE',
    _ => String.fromCharCodes(bytes),
  };
}
