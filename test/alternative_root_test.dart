// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

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

  test('access root file', () {
    schedule(() {
      var handler = createStaticHandler(d.defaultRoot);

      return makeRequest(handler, '/static/root.txt', handlerPath: 'static')
          .then((response) {
        expect(response.statusCode, HttpStatus.OK);
        expect(response.contentLength, 8);
        expect(response.readAsString(), completion('root txt'));
      });
    });
  });

  test('access root file with space', () {
    schedule(() {
      var handler = createStaticHandler(d.defaultRoot);

      return makeRequest(handler, '/static/files/with%20space.txt',
          handlerPath: 'static').then((response) {
        expect(response.statusCode, HttpStatus.OK);
        expect(response.contentLength, 18);
        expect(response.readAsString(), completion('with space content'));
      });
    });
  });

  test('access root file with unencoded space', () {
    schedule(() {
      var handler = createStaticHandler(d.defaultRoot);

      return makeRequest(handler, '/static/files/with%20space.txt',
          handlerPath: 'static').then((response) {
        expect(response.statusCode, HttpStatus.OK);
        expect(response.contentLength, 18);
        expect(response.readAsString(), completion('with space content'));
      });
    });
  });

  test('access file under directory', () {
    schedule(() {
      var handler = createStaticHandler(d.defaultRoot);

      return makeRequest(handler, '/static/files/test.txt',
          handlerPath: 'static').then((response) {
        expect(response.statusCode, HttpStatus.OK);
        expect(response.contentLength, 16);
        expect(response.readAsString(), completion('test txt content'));
      });
    });
  });

  test('file not found', () {
    schedule(() {
      var handler = createStaticHandler(d.defaultRoot);

      return makeRequest(handler, '/static/not_here.txt', handlerPath: 'static')
          .then((response) {
        expect(response.statusCode, HttpStatus.NOT_FOUND);
      });
    });
  });
}
