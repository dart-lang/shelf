// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'package:http_parser/http_parser.dart';

import 'util.dart';

final _emptyHeaders = Headers._empty();

/// Unmodifiable, key-insensitive header map.
class Headers extends UnmodifiableMapView<String, List<String>> {
  late final Map<String, String> singleValues = _HeadersSingleValuesView(this);

  factory Headers.from(Map<String, List<String>>? values) {
    if (values == null || values.isEmpty) {
      return _emptyHeaders;
    } else if (values is Headers) {
      return values;
    } else {
      return Headers._(values.entries);
    }
  }

  factory Headers.fromEntries(
    Iterable<MapEntry<String, List<String>>>? entries,
  ) {
    if (entries == null || (entries is List && entries.isEmpty)) {
      return _emptyHeaders;
    } else {
      return Headers._(entries);
    }
  }

  /// Wraps an already-constructed [CaseInsensitiveMap] of unmodifiable header
  /// value lists without copying entries a second time.
  factory Headers.adopt(CaseInsensitiveMap<List<String>> map) =>
      map.isEmpty ? _emptyHeaders : Headers._adopt(map);

  Headers._adopt(super.map);

  Headers._(Iterable<MapEntry<String, List<String>>> entries)
    : super(
        CaseInsensitiveMap.fromEntries(
          entries
              .where((e) => e.value.isNotEmpty)
              .map((e) => MapEntry(e.key, List.unmodifiable(e.value))),
        ),
      );

  Headers._empty() : super(const {});

  factory Headers.empty() => _emptyHeaders;

  /// Returns a new [Headers] with [changeHeaders] applied on top of `this`.
  Headers updateHeaders(Map<String, Object?> changeHeaders) {
    if (changeHeaders.isEmpty) return this;
    final map = CaseInsensitiveMap<List<String>>.from(this);
    for (final entry in changeHeaders.entries) {
      final val = entry.value;
      if (val == null) {
        map.remove(entry.key);
      } else {
        final expanded = expandHeaderValue(val);
        if (expanded.isEmpty) {
          map.remove(entry.key);
        } else {
          map[entry.key] = List.unmodifiable(expanded);
        }
      }
    }
    return Headers.adopt(map);
  }
}

final class _HeadersSingleValuesView
    extends UnmodifiableMapBase<String, String> {
  final Headers _headers;

  _HeadersSingleValuesView(this._headers);

  @override
  String? operator [](Object? key) {
    if (key is! String) return null;
    final values = _headers[key];
    if (values == null) return null;
    return joinHeaderValues(values, name: key);
  }

  @override
  bool containsKey(Object? key) => _headers.containsKey(key);

  @override
  Iterable<String> get keys => _headers.keys;

  @override
  int get length => _headers.length;

  @override
  bool get isEmpty => _headers.isEmpty;

  @override
  bool get isNotEmpty => _headers.isNotEmpty;
}
