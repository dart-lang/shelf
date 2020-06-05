// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'package:http_parser/http_parser.dart';
import 'package:shelf/src/util.dart';

final _emptyHeaders = Headers._empty();

/// Unmodifiable, key-insensitive header map.
class Headers extends UnmodifiableMapView<String, List<String>> {
  Map<String, String> _singeValues;

  factory Headers.from(Map<String, List<String>> values) {
    if (values == null || values.isEmpty) {
      return _emptyHeaders;
    } else if (values is Headers) {
      return values;
    } else {
      return Headers._(values);
    }
  }

  Headers._(Map<String, List<String>> values)
      : super(
          CaseInsensitiveMap<List<String>>.from(
            Map<String, List<String>>.fromEntries(
              values.entries
                  .where((e) => e.value != null && e.value.isNotEmpty)
                  .map(
                    (e) => MapEntry<String, List<String>>(
                      e.key,
                      List.unmodifiable(e.value),
                    ),
                  ),
            ),
          ),
        );

  Headers._empty() : super(<String, List<String>>{});
  factory Headers.empty() => _emptyHeaders;

  Map<String, String> get singleValues {
    return _singeValues ??= _SingleValueHeaders(
      CaseInsensitiveMap<String>.from(
        map((key, value) =>
            MapEntry<String, String>(key, joinHeaderValues(value))),
      ),
    );
  }
}

class _SingleValueHeaders extends UnmodifiableMapView<String, String> {
  _SingleValueHeaders(Map<String, String> map) : super(map);
}
