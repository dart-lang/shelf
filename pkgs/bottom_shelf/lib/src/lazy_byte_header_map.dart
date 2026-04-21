// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';
import 'package:http_parser/http_parser.dart';
import 'header_slices.dart';

/// A [Map] that lazily converts [HeaderEntrySlices] to strings only when
/// accessed.
final class LazyByteHeaderMap
    extends UnmodifiableMapBase<String, List<String>> {
  final List<HeaderEntrySlices> _slices;

  // TODO(perf): Investigate if it's more efficient to avoid hydrating a map
  // entirely. For a small number of headers (typical in HTTP), a linear scan
  // over `_slices` using `HeaderByteSlice.matches` (which is zero-allocation)
  // might be faster and use less memory than building a full
  // CaseInsensitiveMap.
  //
  // Challenges to consider:
  // 1. O(N) vs O(1) lookup time (though N is usually small).
  // 2. Duplicate keys (must find all matches).
  // 3. Repeated lookups (could be mitigated by a self-organizing list or
  //    small cache).
  //
  // We could also consider sorting the slices by key (case-insensitive byte
  // comparison) to allow binary search or early exit, but the sort overhead
  // might not be worth it for small N.
  CaseInsensitiveMap<List<String>>? _inner;

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
  List<String>? operator [](Object? key) => _map[key];

  @override
  Iterable<String> get keys => _map.keys;

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
