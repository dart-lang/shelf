// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_test.dart';

import 'package:shelf_static/shelf_static.dart';

void main() {
  setUp(() {
    var tempDir;
    schedule(() {
      return Directory.systemTemp.createTemp('shelf_static-test-').then((dir) {
        tempDir = dir;
        d.defaultRoot = tempDir.path;
      });
    });

    d.file('root.txt', 'root txt').create();
    d
        .dir('files', [
      d.file('test.txt', 'test txt content'),
      d.file('with space.txt', 'with space content')
    ])
        .create();

    currentSchedule.onComplete.schedule(() {
      d.defaultRoot = null;
      return tempDir.delete(recursive: true);
    });
  });

  test('non-existent relative path', () {
    schedule(() {
      expect(() => createStaticHandler('random/relative'), throwsArgumentError);
    });
  });

  test('existing relative path', () {
    schedule(() {
      var existingRelative = p.relative(d.defaultRoot);
      expect(() => createStaticHandler(existingRelative), returnsNormally);
    });
  });

  test('non-existent absolute path', () {
    schedule(() {
      var nonExistingAbsolute = p.join(d.defaultRoot, 'not_here');
      expect(
          () => createStaticHandler(nonExistingAbsolute), throwsArgumentError);
    });
  });

  test('existing absolute path', () {
    schedule(() {
      expect(() => createStaticHandler(d.defaultRoot), returnsNormally);
    });
  });
}
