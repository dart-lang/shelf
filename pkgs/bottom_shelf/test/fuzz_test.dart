// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:bottom_shelf/src/exceptions.dart';
import 'package:bottom_shelf/src/raw_http_parser.dart';
import 'package:test/test.dart';

void main() {
  group('RawHttpParser Fuzzing', () {
    final random = Random(42); // Fixed seed for reproducibility
    const iterations = 25000;

    test('Pure random noise does not crash', () {
      final parser = RawHttpParser();

      for (var i = 0; i < iterations; i++) {
        final length = random.nextInt(1024);
        final bytes = Uint8List(length);
        for (var j = 0; j < length; j++) {
          bytes[j] = random.nextInt(256);
        }

        try {
          parser.reset();
          parser.process(bytes);
        } on BadRequestException {
          // Expected parse errors
        } catch (e, st) {
          fail(
            'Parser crashed on random noise at iteration $i!\n'
            'Error: $e\n'
            'Stack trace: $st\n'
            'Bytes: $bytes',
          );
        }
      }
    });

    test('Mutated valid requests do not crash', () {
      final parser = RawHttpParser();
      final validRequest = utf8.encode(
        'GET / HTTP/1.1\r\nHost: localhost\r\n\r\n',
      );

      for (var i = 0; i < iterations; i++) {
        final mutated = Uint8List.fromList(validRequest);
        final mutations = random.nextInt(5) + 1;
        for (var j = 0; j < mutations; j++) {
          final pos = random.nextInt(mutated.length);
          mutated[pos] = random.nextInt(256);
        }

        try {
          parser.reset();
          parser.process(mutated);
        } on BadRequestException {
          // Expected parse errors
        } catch (e, st) {
          fail(
            'Parser crashed on mutated request at iteration $i!\n'
            'Error: $e\n'
            'Stack trace: $st\n'
            'Bytes: $mutated',
          );
        }
      }
    });
  });
}
