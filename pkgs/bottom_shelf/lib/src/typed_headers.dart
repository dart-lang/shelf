// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:http_parser/http_parser.dart';
import 'constants.dart';
import 'exceptions.dart';
import 'header_slices.dart';

/// A specialized header container that uses byte slices for maximum
/// performance.
final class TypedHeaders {
  final List<HeaderEntrySlices> _slices;
  final _cache = <String, Object?>{};

  // Results of the single fused scan over the header slices. Computing
  // these together replaces eight separate walks of the slice list on the
  // per-request hot path.
  int _contentLengthCount = 0;
  bool _contentLengthDigitsValid = true;
  int? _contentLengthValue;
  bool _hasTransferEncoding = false;
  bool _isChunked = false;
  int _hostCount = 0;
  String? _host;
  // 0 = no recognized Connection token, 1 = keep-alive, 2 = close.
  int _connectionToken = 0;

  TypedHeaders(this._slices) {
    for (var slice in _slices) {
      final key = slice.key;
      if (key.matches($Header.contentLength)) {
        _contentLengthCount++;
        final value = slice.value.asString();
        var digitsValid = value.isNotEmpty;
        for (var i = 0; digitsValid && i < value.length; i++) {
          final c = value.codeUnitAt(i);
          if (c < 0x30 || c > 0x39) digitsValid = false;
        }
        if (digitsValid) {
          _contentLengthValue ??= int.tryParse(value);
        } else {
          _contentLengthDigitsValid = false;
        }
      } else if (key.matches($Header.transferEncoding)) {
        _hasTransferEncoding = true;
        if (slice.value.asString().toLowerCase().contains('chunked')) {
          _isChunked = true;
        }
      } else if (key.matches($Header.host)) {
        _hostCount++;
        _host ??= slice.value.asString();
      } else if (_connectionToken == 0 && key.matches($Header.connection)) {
        final value = slice.value.asString().toLowerCase();
        if (value == 'close') {
          _connectionToken = 2;
        } else if (value == 'keep-alive') {
          _connectionToken = 1;
        }
      }
    }
  }

  /// Returns the Content-Length as an integer, or null if missing/invalid.
  int? get contentLength => _contentLengthValue;

  /// The number of Content-Length headers present.
  int get contentLengthHeaderCount => _contentLengthCount;

  /// False if any Content-Length header is empty or contains a non-digit.
  bool get contentLengthDigitsValid => _contentLengthDigitsValid;

  /// True if any Transfer-Encoding header is present.
  bool get hasTransferEncoding => _hasTransferEncoding;

  /// Returns the Content-Type as a [MediaType], or null if missing/invalid.
  MediaType? get contentType =>
      _getTypedHeader($Header.contentType, MediaType.parse);

  /// Returns the If-Modified-Since header as a [DateTime].
  DateTime? get ifModifiedSince =>
      _getTypedHeader($Header.ifModifiedSince, parseHttpDate);

  /// Returns the Host header.
  String? get host => _host;

  /// Returns true if the connection should be kept alive.
  bool isKeepAlive(String protocolVersion) => switch (_connectionToken) {
    2 => false,
    1 => true,
    _ => protocolVersion == '1.1',
  };

  /// Returns true if both Content-Length and Transfer-Encoding are present.
  /// This is a sign of HTTP request smuggling (RFC 9112 section 6.1).
  bool get hasConflictingBodyHeaders =>
      _contentLengthCount > 0 && _hasTransferEncoding;

  /// Returns true if the request contains duplicate Host headers.
  bool get hasDuplicateHost => _hostCount > 1;

  /// Returns true if the request body is chunked.
  bool get isChunked => _isChunked;

  /// Validates that Transfer-Encoding is valid.
  /// Throws [BadRequestException] if invalid.
  void validateTransferEncoding() {
    if (!_hasTransferEncoding) return;
    for (var slice in _slices) {
      if (slice.key.matches($Header.transferEncoding)) {
        final value = slice.value.asString().toLowerCase();
        final encodings = value.split(',').map((e) => e.trim()).toList();
        if (encodings.isEmpty) continue;
        final finalEncoding = encodings.last;
        if (finalEncoding != 'chunked') {
          if (encodings.contains('chunked')) {
            // Chunked is present but not final! MUST be 400!
            throw const BadRequestException(
              'Chunked transfer encoding must be final',
            );
          } else {
            // Chunked not present! We only support chunked!
            throw BadRequestException.fromResponse(
              ErrorResponse.notImplemented,
            );
          }
        }
        if (encodings.length > 1) {
          // Chunked is final, but there are others! We don't support them!
          throw BadRequestException.fromResponse(ErrorResponse.notImplemented);
        }
      }
    }
  }

  T? _getTypedHeader<T>(String headerName, T? Function(String) parse) {
    if (_cache.containsKey(headerName)) {
      return _cache[headerName] as T?;
    }
    for (var slice in _slices) {
      if (slice.key.matches(headerName)) {
        final value = slice.value.asString();
        final parsed = parse(value);
        _cache[headerName] = parsed;
        return parsed;
      }
    }
    _cache[headerName] = null;
    return null;
  }
}
