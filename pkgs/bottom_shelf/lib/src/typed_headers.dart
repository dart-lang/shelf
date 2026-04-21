// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:http_parser/http_parser.dart';
import 'header_slices.dart';

/// A specialized header container that uses byte slices for maximum
/// performance.
final class TypedHeaders {
  final List<HeaderEntrySlices> _slices;
  final Map<String, Object?> _cache = {};

  TypedHeaders(this._slices);

  /// Returns the Content-Length as an integer, or null if missing/invalid.
  int? get contentLength {
    if (_cache case {'content-length': final int? value}) return value;
    for (var slice in _slices) {
      if (slice.key.matches('content-length')) {
        final value = slice.value.asString();
        final parsed = int.tryParse(value);
        _cache['content-length'] = parsed;
        return parsed;
      }
    }
    _cache['content-length'] = null;
    return null;
  }

  /// Returns the Content-Type as a [MediaType], or null if missing/invalid.
  MediaType? get contentType {
    if (_cache case {'content-type': final MediaType? value}) return value;
    for (var slice in _slices) {
      if (slice.key.matches('content-type')) {
        final value = slice.value.asString();
        final parsed = MediaType.parse(value);
        _cache['content-type'] = parsed;
        return parsed;
      }
    }
    _cache['content-type'] = null;
    return null;
  }

  /// Returns the If-Modified-Since header as a [DateTime].
  DateTime? get ifModifiedSince {
    if (_cache case {'if-modified-since': final DateTime? value}) return value;
    for (var slice in _slices) {
      if (slice.key.matches('if-modified-since')) {
        final value = slice.value.asString();
        final parsed = parseHttpDate(value);
        _cache['if-modified-since'] = parsed;
        return parsed;
      }
    }
    _cache['if-modified-since'] = null;
    return null;
  }

  /// Returns the Host header.
  String? get host {
    if (_cache case {'host': final String? value}) return value;
    for (var slice in _slices) {
      if (slice.key.matches('host')) {
        final value = slice.value.asString();
        _cache['host'] = value;
        return value;
      }
    }
    _cache['host'] = null;
    return null;
  }

  /// Returns true if the connection should be kept alive.
  bool isKeepAlive(String protocolVersion) {
    if (_cache case {'keep-alive': final bool value}) return value;
    for (var slice in _slices) {
      if (slice.key.matches('connection')) {
        final value = slice.value.asString().toLowerCase();
        if (value == 'close') {
          _cache['keep-alive'] = false;
          return false;
        }
        if (value == 'keep-alive') {
          _cache['keep-alive'] = true;
          return true;
        }
      }
    }
    final result = protocolVersion == '1.1';
    _cache['keep-alive'] = result;
    return result;
  }

  /// Returns true if both Content-Length and Transfer-Encoding are present.
  /// This is a sign of HTTP request smuggling (RFC 9112 section 6.1).
  bool get hasConflictingBodyHeaders {
    if (_cache case {'conflicting-body-headers': final bool value}) {
      return value;
    }
    var hasContentLength = false;
    var hasTransferEncoding = false;

    for (var slice in _slices) {
      if (slice.key.matches('content-length')) {
        hasContentLength = true;
      } else if (slice.key.matches('transfer-encoding')) {
        hasTransferEncoding = true;
      }
    }

    final result = hasContentLength && hasTransferEncoding;
    _cache['conflicting-body-headers'] = result;
    return result;
  }

  /// Returns true if the request body is chunked.
  bool get isChunked {
    if (_cache case {'is-chunked': final bool value}) return value;
    for (var slice in _slices) {
      if (slice.key.matches('transfer-encoding')) {
        final value = slice.value.asString().toLowerCase();
        if (value.contains('chunked')) {
          _cache['is-chunked'] = true;
          return true;
        }
      }
    }
    _cache['is-chunked'] = false;
    return false;
  }
}
