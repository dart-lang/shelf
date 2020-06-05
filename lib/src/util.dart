// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart';

import 'shelf_unmodifiable_map.dart';

/// Run [callback] and capture any errors that would otherwise be top-leveled.
///
/// If [this] is called in a non-root error zone, it will just run [callback]
/// and return the result. Otherwise, it will capture any errors using
/// [runZoned] and pass them to [onError].
void catchTopLevelErrors(void Function() callback,
    void Function(dynamic error, StackTrace) onError) {
  if (Zone.current.inSameErrorZone(Zone.root)) {
    return runZoned(callback, onError: onError);
  } else {
    return callback();
  }
}

/// Returns a [Map] with the values from [original] and the values from
/// [updates].
///
/// For keys that are the same between [original] and [updates], the value in
/// [updates] is used.
///
/// If [updates] is `null` or empty, [original] is returned unchanged.
Map<K, V> updateMap<K, V>(Map<K, V> original, Map<K, V> updates) {
  if (updates == null || updates.isEmpty) return original;

  return Map.from(original)..addAll(updates);
}

/// Adds a header with [name] and [value] to [headers], which may be null.
///
/// Returns a new map without modifying [headers].
Map<String, dynamic> addHeader(
    Map<String, dynamic> headers, String name, String value) {
  headers = headers == null ? {} : Map.from(headers);
  headers[name] = value;
  return headers;
}

/// Returns the header with the given [name] in [headers].
///
/// This works even if [headers] is `null`, or if it's not yet a
/// case-insensitive map.
String findHeader(Map<String, List<String>> headers, String name) {
  if (headers == null) return null;
  if (headers is ShelfUnmodifiableMap) {
    return joinHeaderValues(headers[name]);
  }

  for (var key in headers.keys) {
    if (equalsIgnoreAsciiCase(key, name)) {
      return joinHeaderValues(headers[key]);
    }
  }
  return null;
}

Map<String, List<String>> expandToHeadersAll(
    Map<String, /* String | List<String> */ dynamic> headers) {
  if (headers is Map<String, List<String>>) return headers;
  if (headers == null || headers.isEmpty) return null;

  return Map<String, List<String>>.fromEntries(headers.entries.map((e) {
    return MapEntry<String, List<String>>(e.key, expandHeaderValue(e.value));
  }));
}

List<String> expandHeaderValue(dynamic v) {
  if (v is String) {
    return [v];
  } else if (v is List<String>) {
    return v;
  } else if (v == null) {
    return null;
  } else {
    throw ArgumentError('Expected String or List<String>, got: `$v`.');
  }
}

/// Multiple header values are joined with commas.
/// See http://tools.ietf.org/html/draft-ietf-httpbis-p1-messaging-21#page-22
String joinHeaderValues(List<String> values) {
  if (values == null || values.isEmpty) return null;
  if (values.length == 1) return values.single;
  return values.join(',');
}
