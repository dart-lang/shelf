// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library shelf_static.directory_listing_test;

import 'dart:io';

import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_test.dart';
import 'package:shelf_static/shelf_static.dart';

import 'test_util.dart';

void main() {
  setUp(() {
    var tempDir;
    schedule(() {
      return Directory.systemTemp.createTemp('shelf_static-test-').then((dir) {
        tempDir = dir;
        d.defaultRoot = tempDir.path;
      });
    });

    d.file('index.html', '<html></html>').create();
    d.file('root.txt', 'root txt').create();
    d
        .dir('files', [
      d.file('index.html', '<html><body>files</body></html>'),
      d.file('with space.txt', 'with space content'),
      d.dir('empty subfolder', []),
    ])
        .create();

    currentSchedule.onComplete.schedule(() {
      d.defaultRoot = null;
      return tempDir.delete(recursive: true);
    });
  });

  group('list directories', () {
    test('access "/"', () {
      schedule(() async {
        var handler = createStaticHandler(d.defaultRoot, listDirectories: true);

        return makeRequest(handler, '/').then((response) {
          expect(response.statusCode, HttpStatus.OK);
          expect(response.readAsString(), completes);
        });
      });
    });

    test('access "/files"', () {
      schedule(() async {
        var handler = createStaticHandler(d.defaultRoot, listDirectories: true);

        return makeRequest(handler, '/files').then((response) {
          expect(response.statusCode, HttpStatus.MOVED_PERMANENTLY);
          expect(response.headers,
              containsPair(HttpHeaders.LOCATION, 'http://localhost/files/'));
        });
      });
    });

    test('access "/files/"', () {
      schedule(() async {
        var handler = createStaticHandler(d.defaultRoot, listDirectories: true);

        return makeRequest(handler, '/files/').then((response) {
          expect(response.statusCode, HttpStatus.OK);
          expect(response.readAsString(), completes);
        });
      });
    });

    test('access "/files/empty subfolder"', () {
      schedule(() async {
        var handler = createStaticHandler(d.defaultRoot, listDirectories: true);

        return makeRequest(handler, '/files/empty subfolder').then((response) {
          expect(response.statusCode, HttpStatus.MOVED_PERMANENTLY);
          expect(response.headers, containsPair(HttpHeaders.LOCATION,
              'http://localhost/files/empty%20subfolder/'));
        });
      });
    });

    test('access "/files/empty subfolder/"', () {
      schedule(() async {
        var handler = createStaticHandler(d.defaultRoot, listDirectories: true);

        return makeRequest(handler, '/files/empty subfolder/').then((response) {
          expect(response.statusCode, HttpStatus.OK);
          expect(response.readAsString(), completes);
        });
      });
    });
  });
}
