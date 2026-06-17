// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';
import 'package:http_parser/http_parser.dart';
import 'package:shelf/src/headers.dart';
import 'package:shelf/src/util.dart';
import 'header_slices.dart';

/// A [Map] that lazily converts [HeaderEntrySlices] to strings only when
/// accessed, implementing [Headers] for zero-copy shelf integration.
final class LazyByteHeaderMap extends UnmodifiableMapBase<String, List<String>>
    implements Headers {
  final List<HeaderEntrySlices> _slices;

  CaseInsensitiveMap<List<String>>? _inner;
  Map<String, String>? _singleValues;

  LazyByteHeaderMap(this._slices);

  CaseInsensitiveMap<List<String>> get _map {
    if (_inner == null) {
      final map = _inner = CaseInsensitiveMap<List<String>>();
      for (var slice in _slices) {
        map
            .putIfAbsent(slice.key.asString(), () => [])
            .add(slice.value.asString());
      }
    }
    return _inner!;
  }

  @override
  Map<String, String> get singleValues =>
      _singleValues ??= _LazySingleHeaderMap(this);

  @override
  List<String>? operator [](Object? key) {
    if (key is! String) return null;
    if (_inner != null) return _inner![key];
    List<String>? result;
    for (var slice in _slices) {
      if (slice.key.matchesKey(key)) {
        (result ??= []).add(slice.value.asString());
      }
    }
    return result;
  }

  @override
  bool containsKey(Object? key) {
    if (key is! String) return false;
    if (_inner != null) return _inner!.containsKey(key);
    for (var slice in _slices) {
      if (slice.key.matchesKey(key)) return true;
    }
    return false;
  }

  @override
  Iterable<String> get keys => _map.keys;

  @override
  int get length => _map.length;

  @override
  bool get isEmpty => _slices.isEmpty;

  @override
  bool get isNotEmpty => _slices.isNotEmpty;

  @override
  Iterable<MapEntry<String, List<String>>> get entries => _map.entries;

  @override
  void forEach(void Function(String key, List<String> value) action) =>
      _map.forEach(action);
}

final class _LazySingleHeaderMap extends UnmodifiableMapBase<String, String> {
  final LazyByteHeaderMap _parent;
  CaseInsensitiveMap<String>? _inner;

  _LazySingleHeaderMap(this._parent);

  CaseInsensitiveMap<String> get _map {
    if (_inner == null) {
      final map = _inner = CaseInsensitiveMap<String>();
      _parent.forEach((key, values) {
        map[key] = joinHeaderValues(values)!;
      });
    }
    return _inner!;
  }

  @override
  String? operator [](Object? key) {
    if (key is! String) return null;
    if (_inner != null) return _inner![key];
    final values = _parent[key];
    if (values == null) return null;
    return joinHeaderValues(values);
  }

  @override
  bool containsKey(Object? key) => _parent.containsKey(key);

  @override
  Iterable<String> get keys => _map.keys;

  @override
  int get length => _map.length;
}
