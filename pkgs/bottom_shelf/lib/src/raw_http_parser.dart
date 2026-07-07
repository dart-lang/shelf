// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

import 'constants.dart';
import 'exceptions.dart';
import 'header_slices.dart';
import 'utils.dart';

/// The parsed head of an HTTP request.
typedef HttpRequestHead = ({
  String method,
  String url,
  String version,
  List<HeaderEntrySlices> headerSlices,
  int consumedInLastChunk,
});

extension type const _$State(int _) {
  static const _$State method = _$State(0);
  static const _$State url = _$State(1);
  static const _$State version = _$State(2);
  static const _$State headerKey = _$State(3);
  static const _$State headerValue = _$State(4);
  static const _$State endOfHeaders = _$State(5);
}

/// A high-performance, minimal HTTP/1.1 parser that uses byte slices.
final class RawHttpParser {
  final _headerSlices = <HeaderEntrySlices>[];

  /// Internal buffer to accumulate header bytes across chunks.
  final Uint8List _buffer = Uint8List($Limit.maxHeaderSize);
  int _bufferPos = 0;

  _$State _state = _$State.method;
  String? _method;
  String? _url;
  String? _version;

  int _currentFieldStart = 0;
  HeaderByteSlice? _lastKeySlice;

  /// Shared by all slices from the current request. Invalidated on [reset] so
  /// that slices retained past the response can no longer read the (about to
  /// be reused) buffer.
  SliceBufferToken _token = SliceBufferToken();

  int _totalHeadersReceived = 0;
  int _consumedInLastChunk = 0;

  void reset() {
    _state = _$State.method;
    _method = null;
    _url = null;
    _version = null;
    _headerSlices.clear();
    _bufferPos = 0;
    _currentFieldStart = 0;
    _lastKeySlice = null;
    _totalHeadersReceived = 0;
    // Poison the previous request's slices, then start a fresh batch. The
    // buffer bytes are about to be overwritten by the next request.
    _token.invalidate();
    _token = SliceBufferToken();
  }

  HttpRequestHead? process(Uint8List data) {
    _consumedInLastChunk = 0;
    for (var i = 0; i < data.length; i++) {
      _consumedInLastChunk++;
      final byte = data[i];
      _totalHeadersReceived++;

      if (_totalHeadersReceived > $Limit.maxHeaderSize) {
        throw BadRequestException.fromResponse(
          ErrorResponse.headerFieldsTooLarge,
        );
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
        case _$State.method:
          if (byte == $Chars.sp) {
            _method = _getMethod(_bufferPos - 1);
            _currentFieldStart = _bufferPos;
            _state = _$State.url;
          } else {
            if (byte == 0 || byte == $Chars.lf || byte == $Chars.cr) {
              throw const BadRequestException('Invalid character in method');
            }
            if (_bufferPos - _currentFieldStart > $Limit.maxFieldSize) {
              throw const BadRequestException('Method too long');
            }
          }
        case _$State.url:
          if (byte == $Chars.sp) {
            _url = String.fromCharCodes(
              _buffer,
              _currentFieldStart,
              _bufferPos - 1,
            );
            if (_url == '*' && _method != 'OPTIONS') {
              throw const BadRequestException(
                'Asterisk-form only allowed for OPTIONS',
              );
            }
            _currentFieldStart = _bufferPos;
            _state = _$State.version;
          } else {
            if (isInvalidUrlChar(byte)) {
              throw const BadRequestException('Invalid character in URL');
            }
            if (_bufferPos - _currentFieldStart > $Limit.maxUrlSize) {
              throw BadRequestException.fromResponse(ErrorResponse.uriTooLong);
            }
          }
        case _$State.version:
          if (byte == $Chars.lf) {
            if (_bufferPos < 2 || _buffer[_bufferPos - 2] != $Chars.cr) {
              throw const BadRequestException('Bare line feed not allowed');
            }
            final start = _currentFieldStart;
            final end = _bufferPos - 2;
            if (end - start == 8 &&
                _buffer[start] == 72 && // H
                _buffer[start + 1] == 84 && // T
                _buffer[start + 2] == 84 && // T
                _buffer[start + 3] == 80 && // P
                _buffer[start + 4] == 47 && // /
                _buffer[start + 5] == 49 && // 1
                _buffer[start + 6] == 46 && // .
                _buffer[start + 7] == 49) {
              // 1
              _version = '1.1';
            } else {
              final v = String.fromCharCodes(_buffer, start, end).trim();
              final versionStr = v.startsWith('HTTP/') ? v.substring(5) : v;
              if (!versionStr.startsWith('1.')) {
                throw const BadRequestException('Unsupported HTTP version');
              }
              _version = versionStr;
            }
            _currentFieldStart = _bufferPos;
            _state = _$State.headerKey;
          } else {
            if (byte == 0) {
              throw const BadRequestException('Invalid character in version');
            }
            if (_bufferPos - _currentFieldStart > 64) {
              throw const BadRequestException('Version too long');
            }
          }
        case _$State.headerKey:
          if (byte == $Chars.colon) {
            final start = _currentFieldStart;
            final end = _bufferPos - 1;

            if (end > start &&
                (_buffer[start] == $Chars.sp ||
                    _buffer[end - 1] == $Chars.sp)) {
              throw const BadRequestException(
                'Invalid whitespace in header key',
              );
            }

            if (start == end) {
              throw const BadRequestException('Empty header name');
            }

            _lastKeySlice = HeaderByteSlice(_buffer, start, end, _token);
            _currentFieldStart = _bufferPos;
            _state = _$State.headerValue;
          } else if (byte == $Chars.lf) {
            if (_bufferPos < 2 || _buffer[_bufferPos - 2] != $Chars.cr) {
              throw const BadRequestException('Bare line feed not allowed');
            }
            final len = _bufferPos - _currentFieldStart;
            if (len == 2) {
              _state = _$State.endOfHeaders;
              return (
                method: _method!,
                url: _url!,
                version: _version!,
                headerSlices: List.of(_headerSlices, growable: false),
                consumedInLastChunk: _consumedInLastChunk,
              );
            }
            throw const BadRequestException('Header line without colon');
          } else if (byte != $Chars.cr && !isTchar(byte)) {
            throw const BadRequestException('Invalid character in header key');
          }
        case _$State.headerValue:
          if (byte == $Chars.lf) {
            if (_bufferPos < 2 || _buffer[_bufferPos - 2] != $Chars.cr) {
              throw const BadRequestException('Bare line feed not allowed');
            }
            var start = _currentFieldStart;
            final end = _bufferPos - 2; // Exclude CRLF
            while (start < end && _buffer[start] == $Chars.sp) {
              start++;
            }

            final valueSlice = HeaderByteSlice(_buffer, start, end, _token);
            _headerSlices.add(HeaderEntrySlices(_lastKeySlice!, valueSlice));
            _currentFieldStart = _bufferPos;
            _state = _$State.headerKey;
          } else if (isInvalidHeaderValueChar(byte)) {
            throw const BadRequestException(
              'Invalid character in header value',
            );
          }
      }
    }
    return null;
  }

  /// The method always starts at index 0 of [_buffer] and ends at [end].
  /// Byte comparisons avoid allocating a view for the common methods.
  String _getMethod(int end) {
    final b = _buffer;
    return switch (end) {
      3 when b[0] == 71 && b[1] == 69 && b[2] == 84 => 'GET',
      3 when b[0] == 80 && b[1] == 85 && b[2] == 84 => 'PUT',
      4 when b[0] == 80 && b[1] == 79 && b[2] == 83 && b[3] == 84 => 'POST',
      6
          when b[0] == 68 &&
              b[1] == 69 &&
              b[2] == 76 &&
              b[3] == 69 &&
              b[4] == 84 &&
              b[5] == 69 =>
        'DELETE',
      _ => String.fromCharCodes(b, 0, end),
    };
  }
}
