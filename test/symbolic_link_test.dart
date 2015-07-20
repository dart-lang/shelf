// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library shelf_static.symbolic_link_test;

import 'dart:io';
import 'package:path/path.dart' as p;
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

    d.dir('originals', [d.file('index.html', '<html></html>'),]).create();

    d.dir('alt_root').create();

    schedule(() {
      var originalsDir = p.join(d.defaultRoot, 'originals');
      var originalsIndex = p.join(originalsDir, 'index.html');

      new Link(p.join(d.defaultRoot, 'link_index.html'))
          .createSync(originalsIndex);

      new Link(p.join(d.defaultRoot, 'link_dir')).createSync(originalsDir);

      new Link(p.join(d.defaultRoot, 'alt_root', 'link_index.html'))
          .createSync(originalsIndex);

      new Link(p.join(d.defaultRoot, 'alt_root', 'link_dir'))
          .createSync(originalsDir);
    });

    currentSchedule.onComplete.schedule(() {
      d.defaultRoot = null;
      return tempDir.delete(recursive: true);
    });
  });

  group('access outside of root disabled', () {
    test('access real file', () {
      schedule(() {
        var handler = createStaticHandler(d.defaultRoot);

        return makeRequest(handler, '/originals/index.html').then((response) {
          expect(response.statusCode, HttpStatus.OK);
          expect(response.contentLength, 13);
          expect(response.readAsString(), completion('<html></html>'));
        });
      });
    });

    group('links under root dir', () {
      test('access sym linked file in real dir', () {
        schedule(() {
          var handler = createStaticHandler(d.defaultRoot);

          return makeRequest(handler, '/link_index.html').then((response) {
            expect(response.statusCode, HttpStatus.OK);
            expect(response.contentLength, 13);
            expect(response.readAsString(), completion('<html></html>'));
          });
        });
      });

      test('access file in sym linked dir', () {
        schedule(() {
          var handler = createStaticHandler(d.defaultRoot);

          return makeRequest(handler, '/link_dir/index.html').then((response) {
            expect(response.statusCode, HttpStatus.OK);
            expect(response.contentLength, 13);
            expect(response.readAsString(), completion('<html></html>'));
          });
        });
      });
    });

    group('links not under root dir', () {
      test('access sym linked file in real dir', () {
        schedule(() {
          var handler = createStaticHandler(p.join(d.defaultRoot, 'alt_root'));

          return makeRequest(handler, '/link_index.html').then((response) {
            expect(response.statusCode, HttpStatus.NOT_FOUND);
          });
        });
      });

      test('access file in sym linked dir', () {
        schedule(() {
          var handler = createStaticHandler(p.join(d.defaultRoot, 'alt_root'));

          return makeRequest(handler, '/link_dir/index.html').then((response) {
            expect(response.statusCode, HttpStatus.NOT_FOUND);
          });
        });
      });
    });
  });

  group('access outside of root enabled', () {
    test('access real file', () {
      schedule(() {
        var handler =
            createStaticHandler(d.defaultRoot, serveFilesOutsidePath: true);

        return makeRequest(handler, '/originals/index.html').then((response) {
          expect(response.statusCode, HttpStatus.OK);
          expect(response.contentLength, 13);
          expect(response.readAsString(), completion('<html></html>'));
        });
      });
    });

    group('links under root dir', () {
      test('access sym linked file in real dir', () {
        schedule(() {
          var handler =
              createStaticHandler(d.defaultRoot, serveFilesOutsidePath: true);

          return makeRequest(handler, '/link_index.html').then((response) {
            expect(response.statusCode, HttpStatus.OK);
            expect(response.contentLength, 13);
            expect(response.readAsString(), completion('<html></html>'));
          });
        });
      });

      test('access file in sym linked dir', () {
        schedule(() {
          var handler =
              createStaticHandler(d.defaultRoot, serveFilesOutsidePath: true);

          return makeRequest(handler, '/link_dir/index.html').then((response) {
            expect(response.statusCode, HttpStatus.OK);
            expect(response.contentLength, 13);
            expect(response.readAsString(), completion('<html></html>'));
          });
        });
      });
    });

    group('links not under root dir', () {
      test('access sym linked file in real dir', () {
        schedule(() {
          var handler = createStaticHandler(p.join(d.defaultRoot, 'alt_root'),
              serveFilesOutsidePath: true);

          return makeRequest(handler, '/link_index.html').then((response) {
            expect(response.statusCode, HttpStatus.OK);
            expect(response.contentLength, 13);
            expect(response.readAsString(), completion('<html></html>'));
          });
        });
      });

      test('access file in sym linked dir', () {
        schedule(() {
          var handler = createStaticHandler(p.join(d.defaultRoot, 'alt_root'),
              serveFilesOutsidePath: true);

          return makeRequest(handler, '/link_dir/index.html').then((response) {
            expect(response.statusCode, HttpStatus.OK);
            expect(response.contentLength, 13);
            expect(response.readAsString(), completion('<html></html>'));
          });
        });
      });
    });
  });
}
