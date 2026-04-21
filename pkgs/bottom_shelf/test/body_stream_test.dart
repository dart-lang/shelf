// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'package:bottom_shelf/src/body_stream.dart';
import 'package:test/test.dart';

void main() {
  group('FixedLengthBodyController', () {
    test('triggers onPause and onResume', () async {
      var onPauseCalled = false;
      var onResumeCalled = false;
      final controller = FixedLengthBodyController(
        10,
        () {},
        onPause: () => onPauseCalled = true,
        onResume: () => onResumeCalled = true,
      );

      final subscription = controller.stream.listen((_) {});

      // Wait for listen to register
      await Future<void>.delayed(Duration.zero);

      subscription.pause();
      // StreamController callbacks are async
      await Future<void>.delayed(Duration.zero);
      expect(onPauseCalled, isTrue);

      subscription.resume();
      await Future<void>.delayed(Duration.zero);
      expect(onResumeCalled, isTrue);

      await subscription.cancel();
    });
  });

  group('ChunkedBodyController', () {
    test('triggers onPause and onResume', () async {
      var onPauseCalled = false;
      var onResumeCalled = false;
      final controller = ChunkedBodyController(
        () {},
        onPause: () => onPauseCalled = true,
        onResume: () => onResumeCalled = true,
      );

      final subscription = controller.stream.listen((_) {});

      await Future<void>.delayed(Duration.zero);

      subscription.pause();
      await Future<void>.delayed(Duration.zero);
      expect(onPauseCalled, isTrue);

      subscription.resume();
      await Future<void>.delayed(Duration.zero);
      expect(onResumeCalled, isTrue);

      await subscription.cancel();
    });
  });
}
