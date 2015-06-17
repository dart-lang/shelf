// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library shelf.util;

import 'dart:async';

/// Like [new Future], but avoids around issue 11911 by using [new Future.value]
/// under the covers.
Future newFuture(callback()) => new Future.value().then((_) => callback());

/// Run [callback] and capture any errors that would otherwise be top-leveled.
///
/// If [this] is called in a non-root error zone, it will just run [callback]
/// and return the result. Otherwise, it will capture any errors using
/// [runZoned] and pass them to [onError].
catchTopLevelErrors(callback(), void onError(error, StackTrace stackTrace)) {
  if (Zone.current.inSameErrorZone(Zone.ROOT)) {
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
Map updateMap(Map original, Map updates) {
  if (updates == null || updates.isEmpty) return original;

  return new Map.from(original)..addAll(updates);
}

/// Adds a header with [name] and [value] to [headers], which may be null.
///
/// Returns a new map without modifying [headers].
Map<String, String> addHeader(
    Map<String, String> headers, String name, String value) {
  headers = headers == null ? {} : new Map.from(headers);
  headers[name] = value;
  return headers;
}
