// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';
import 'package:http_parser/http_parser.dart';
import 'header_slices.dart';

/// A [Map] that lazily converts [HeaderEntrySlices] to strings only when accessed.
final class LazyByteHeaderMap extends MapBase<String, List<String>> {
  final List<HeaderEntrySlices> _slices;
  CaseInsensitiveMap<List<String>>? _inner;

  LazyByteHeaderMap(this._slices);

  CaseInsensitiveMap<List<String>> get _map {
    if (_inner != null) return _inner!;
    final map = CaseInsensitiveMap<List<String>>();
    for (var slice in _slices) {
      final key = String.fromCharCodes(
          slice.key.buffer, slice.key.start, slice.key.end);
      final value = String.fromCharCodes(
          slice.value.buffer, slice.value.start, slice.value.end);
      map.putIfAbsent(key, () => []).add(value);
    }
    return _inner = map;
  }

  @override
  List<String>? operator [](Object? key) => _map[key];

  @override
  void operator []=(String key, List<String> value) =>
      throw UnsupportedError('Unmodifiable');

  @override
  void clear() => throw UnsupportedError('Unmodifiable');

  @override
  Iterable<String> get keys => _map.keys;

  @override
  List<String>? remove(Object? key) => throw UnsupportedError('Unmodifiable');

  @override
  bool containsKey(Object? key) => _map.containsKey(key);

  @override
  int get length => _map.length;

  @override
  Iterable<MapEntry<String, List<String>>> get entries => _map.entries;

  @override
  void forEach(void Function(String key, List<String> value) action) =>
      _map.forEach(action);
}
