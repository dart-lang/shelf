// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:bottom_shelf/src/raw_http_parser.dart';
import 'package:test/test.dart';

void main() {
  group('parser slice invalidation (cross-request buffer reuse)', () {
    test('slices read fine before reset', () {
      final parser = RawHttpParser();
      final head = parser.process(
        Uint8List.fromList(
          utf8.encode('GET /a HTTP/1.1\r\nHost: first.example\r\n\r\n'),
        ),
      )!;
      expect(head.headerSlices.single.value.asString(), 'first.example');
    });

    test(
      'slices retained past reset throw instead of leaking next request',
      () {
        final parser = RawHttpParser();
        final head = parser.process(
          Uint8List.fromList(
            utf8.encode('GET /a HTTP/1.1\r\nHost: first.example\r\n\r\n'),
          ),
        )!;
        final retained = head.headerSlices.single.value;

        // Simulate the keep-alive lifecycle: response written, buffer reset,
        // next request parsed into the same buffer.
        parser.reset();
        parser.process(
          Uint8List.fromList(
            utf8.encode('GET /b HTTP/1.1\r\nHost: second.example\r\n\r\n'),
          ),
        );

        // The retained slice must not silently return "second.example".
        expect(retained.asString, throwsStateError);
      },
    );

    test('matchesKey on a retained slice also throws after reset', () {
      final parser = RawHttpParser();
      final head = parser.process(
        Uint8List.fromList(
          utf8.encode('GET /a HTTP/1.1\r\nHost: first.example\r\n\r\n'),
        ),
      )!;
      final retainedKey = head.headerSlices.single.key;
      parser.reset();
      expect(() => retainedKey.matchesKey('host'), throwsStateError);
    });
  });
}
