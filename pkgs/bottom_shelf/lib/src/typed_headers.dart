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

  TypedHeaders(this._slices);

  /// Returns the Content-Length as an integer, or null if missing/invalid.
  int? get contentLength =>
      _getTypedHeader($Header.contentLength, int.tryParse);

  /// Returns the Content-Type as a [MediaType], or null if missing/invalid.
  MediaType? get contentType =>
      _getTypedHeader($Header.contentType, MediaType.parse);

  /// Returns the If-Modified-Since header as a [DateTime].
  DateTime? get ifModifiedSince =>
      _getTypedHeader($Header.ifModifiedSince, parseHttpDate);

  /// Returns the Host header.
  String? get host => _getTypedHeader($Header.host, (s) => s);

  /// Returns true if the connection should be kept alive.
  bool isKeepAlive(String protocolVersion) {
    if (_cache case {_CacheKey.keepAlive: final bool value}) return value;
    for (var slice in _slices) {
      if (slice.key.matches($Header.connection)) {
        final value = slice.value.asString().toLowerCase();
        if (value == 'close') {
          _cache[_CacheKey.keepAlive] = false;
          return false;
        }
        if (value == 'keep-alive') {
          _cache[_CacheKey.keepAlive] = true;
          return true;
        }
      }
    }
    final result = protocolVersion == '1.1';
    _cache[_CacheKey.keepAlive] = result;
    return result;
  }

  /// Returns true if both Content-Length and Transfer-Encoding are present.
  /// This is a sign of HTTP request smuggling (RFC 9112 section 6.1).
  bool get hasConflictingBodyHeaders {
    if (_cache case {_CacheKey.conflictingBodyHeaders: final bool value}) {
      return value;
    }
    var hasContentLength = false;
    var hasTransferEncoding = false;

    for (var slice in _slices) {
      if (slice.key.matches($Header.contentLength)) {
        hasContentLength = true;
      } else if (slice.key.matches($Header.transferEncoding)) {
        hasTransferEncoding = true;
      }
    }

    final result = hasContentLength && hasTransferEncoding;
    _cache[_CacheKey.conflictingBodyHeaders] = result;
    return result;
  }

  /// Returns true if the request contains duplicate Host headers.
  bool get hasDuplicateHost {
    var count = 0;
    for (var slice in _slices) {
      if (slice.key.matches($Header.host)) {
        count++;
        if (count > 1) return true;
      }
    }
    return false;
  }

  /// Returns true if the request body is chunked.
  bool get isChunked {
    if (_cache case {_CacheKey.isChunked: final bool value}) return value;
    for (var slice in _slices) {
      if (slice.key.matches($Header.transferEncoding)) {
        final value = slice.value.asString().toLowerCase();
        if (value.contains('chunked')) {
          _cache[_CacheKey.isChunked] = true;
          return true;
        }
      }
    }
    _cache[_CacheKey.isChunked] = false;
    return false;
  }

  /// Validates that Transfer-Encoding is valid.
  /// Throws [BadRequestException] if invalid.
  void validateTransferEncoding() {
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

abstract final class _CacheKey {
  static const keepAlive = '[keep-alive]';
  static const conflictingBodyHeaders = '[conflicting-body-headers]';
  static const isChunked = '[is-chunked]';
}
