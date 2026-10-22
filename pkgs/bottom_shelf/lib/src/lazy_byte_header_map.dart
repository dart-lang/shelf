// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:http_parser/http_parser.dart';
import 'package:shelf/shelf.dart';
// ignore: implementation_imports
import 'package:shelf/src/util.dart';

import 'header_slices.dart';

/// A [Map] that lazily converts [HeaderEntrySlices] to strings only when
/// accessed, implementing [Headers] for zero-copy shelf integration.
final class LazyByteHeaderMap extends UnmodifiableMapBase<String, List<String>>
    implements Headers {
  final List<HeaderEntrySlices> _slices;
  final CaseInsensitiveMap<List<String>?>? _overrides;

  CaseInsensitiveMap<List<String>>? _inner;
  Map<String, String>? _singleValues;

  LazyByteHeaderMap(this._slices) : _overrides = null;

  LazyByteHeaderMap._(this._slices, this._overrides);

  @override
  Headers updateHeaders(Map<String, Object?> changeHeaders) {
    if (changeHeaders.isEmpty) return this;
    if (_inner != null) {
      final map = CaseInsensitiveMap<List<String>>.from(_inner!);
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

    final overrides = _overrides == null
        ? CaseInsensitiveMap<List<String>?>()
        : CaseInsensitiveMap<List<String>?>.from(_overrides);
    for (final entry in changeHeaders.entries) {
      final val = entry.value;
      if (val == null) {
        overrides[entry.key] = null;
      } else {
        final expanded = expandHeaderValue(val);
        if (expanded.isEmpty) {
          overrides[entry.key] = null;
        } else {
          overrides[entry.key] = List.unmodifiable(expanded);
        }
      }
    }
    return LazyByteHeaderMap._(_slices, overrides);
  }

  CaseInsensitiveMap<List<String>> get _map {
    if (_inner == null) {
      final map = _inner = CaseInsensitiveMap<List<String>>();
      for (var slice in _slices) {
        map
            .putIfAbsent(slice.key.asString(), () => [])
            .add(slice.value.asString());
      }
      final overrides = _overrides;
      if (overrides != null) {
        overrides.forEach((key, value) {
          if (value == null) {
            map.remove(key);
          } else {
            map[key] = value;
          }
        });
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
    final overrides = _overrides;
    if (overrides != null && overrides.containsKey(key)) {
      return overrides[key];
    }
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
    final overrides = _overrides;
    if (overrides != null && overrides.containsKey(key)) {
      return overrides[key] != null;
    }
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
  bool get isEmpty => _overrides == null ? _slices.isEmpty : _map.isEmpty;

  @override
  bool get isNotEmpty =>
      _overrides == null ? _slices.isNotEmpty : _map.isNotEmpty;

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
      if (_parent._inner != null) {
        _parent._inner!.forEach((key, values) {
          map[key] = joinHeaderValues(values, name: key)!;
        });
      } else {
        for (var slice in _parent._slices) {
          final key = slice.key.asString();
          final val = slice.value.asString();
          final existing = map[key];
          if (existing == null) {
            map[key] = val;
          } else {
            final sep = equalsIgnoreAsciiCase(key, 'cookie') ? '; ' : ',';
            map[key] = '$existing$sep$val';
          }
        }
        final overrides = _parent._overrides;
        if (overrides != null) {
          overrides.forEach((key, values) {
            if (values == null) {
              map.remove(key);
            } else {
              map[key] = joinHeaderValues(values, name: key)!;
            }
          });
        }
      }
    }
    return _inner!;
  }

  @override
  String? operator [](Object? key) {
    if (key is! String) return null;
    if (_inner != null) return _inner![key];
    final values = _parent[key];
    if (values == null) return null;
    return joinHeaderValues(values, name: key);
  }

  @override
  bool containsKey(Object? key) => _parent.containsKey(key);

  @override
  Iterable<String> get keys => _map.keys;

  @override
  int get length => _map.length;
}
