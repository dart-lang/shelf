// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:http_parser/http_parser.dart';
import 'header_slices.dart';

/// A specialized header container that uses byte slices for maximum performance.
class TypedHeaders {
  final List<HeaderEntrySlices> _slices;
  final Map<String, Object?> _cache = {};

  TypedHeaders(this._slices);

  /// Returns the Content-Length as an integer, or null if missing/invalid.
  int? get contentLength {
    if (_cache.containsKey('content-length')) {
      return _cache['content-length'] as int?;
    }
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
    if (_cache.containsKey('content-type')) {
      return _cache['content-type'] as MediaType?;
    }
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
    if (_cache.containsKey('if-modified-since')) {
      return _cache['if-modified-since'] as DateTime?;
    }
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
    if (_cache.containsKey('host')) return _cache['host'] as String?;
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
    if (_cache.containsKey('keep-alive')) return _cache['keep-alive'] as bool;
    for (var slice in _slices) {
      if (slice.key.matches('connection')) {
        final value = slice.value.asString().toLowerCase();
        final result = value == 'keep-alive';
        _cache['keep-alive'] = result;
        return result;
      }
    }
    final result = protocolVersion == '1.1';
    _cache['keep-alive'] = result;
    return result;
  }
}
