// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:http_parser/http_parser.dart';

/// A simple wrapper over [UnmodifiableMapView] which avoids re-wrapping itself.
class ShelfUnmodifiableMap<V> extends UnmodifiableMapView<String, V> {
  /// `true` if the key values are already lowercase.
  final bool _ignoreKeyCase;

  /// If [source] is a [ShelfUnmodifiableMap] with matching [ignoreKeyCase],
  /// then [source] is returned.
  ///
  /// If [source] is `null` it is treated like an empty map.
  ///
  /// If [ignoreKeyCase] is `true`, the keys will have case-insensitive access.
  ///
  /// [source] is copied to a new [Map] to ensure changes to the parameter value
  /// after constructions are not reflected.
  factory ShelfUnmodifiableMap(Map<String, V> source,
      {bool ignoreKeyCase = false}) {
    if (source is ShelfUnmodifiableMap<V> &&
        //        !ignoreKeyCase: no transformation of the input is required
        // source._ignoreKeyCase: the input cannot be transformed any more
        (!ignoreKeyCase || source._ignoreKeyCase)) {
      return source;
    }

    if (source == null || source.isEmpty) {
      return const _EmptyShelfUnmodifiableMap();
    }

    if (ignoreKeyCase) {
      source = CaseInsensitiveMap<V>.from(source);
    } else {
      source = Map<String, V>.from(source);
    }

    return ShelfUnmodifiableMap<V>._(source, ignoreKeyCase);
  }

  /// Returns an empty [ShelfUnmodifiableMap].
  const factory ShelfUnmodifiableMap.empty() = _EmptyShelfUnmodifiableMap<V>;

  ShelfUnmodifiableMap._(Map<String, V> source, this._ignoreKeyCase)
      : super(source);
}

/// A const implementation of an empty [ShelfUnmodifiableMap].
class _EmptyShelfUnmodifiableMap<V> extends MapView<String, V>
    implements ShelfUnmodifiableMap<V> {
  @override
  bool get _ignoreKeyCase => true;
  const _EmptyShelfUnmodifiableMap() : super(const <String, Null>{});

  // Override modifier methods that care about the type of key they use so that
  // when V is Null, they throw UnsupportedErrors instead of type errors.
  @override
  void operator []=(String key, Object value) => super[key] = null;
  @override
  void addAll(Map<String, Object> other) => super.addAll({});
  @override
  V putIfAbsent(String key, Object Function() ifAbsent) =>
      super.putIfAbsent(key, () => null);
}
