// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library shelf_static.default_document_test;

import 'dart:io';
//import 'package:http_parser/http_parser.dart';
//import 'package:path/path.dart' as p;
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
      d.file('with space.txt', 'with space content')
    ])
        .create();

    currentSchedule.onComplete.schedule(() {
      d.defaultRoot = null;
      return tempDir.delete(recursive: true);
    });
  });

  group('default document value', () {
    test('cannot contain slashes', () {
      var invalidValues = [
        'file/foo.txt',
        '/bar.txt',
        '//bar.txt',
        '//news/bar.txt',
        'foo/../bar.txt'
      ];

      for (var val in invalidValues) {
        expect(() => createStaticHandler(d.defaultRoot, defaultDocument: val),
            throwsArgumentError);
      }
    });
  });

  group('no default document specified', () {
    test('access "/index.html"', () {
      schedule(() {
        var handler = createStaticHandler(d.defaultRoot);

        return makeRequest(handler, '/index.html').then((response) {
          expect(response.statusCode, HttpStatus.OK);
          expect(response.contentLength, 13);
          expect(response.readAsString(), completion('<html></html>'));
        });
      });
    });

    test('access "/"', () {
      schedule(() {
        var handler = createStaticHandler(d.defaultRoot);

        return makeRequest(handler, '/').then((response) {
          expect(response.statusCode, HttpStatus.NOT_FOUND);
        });
      });
    });

    test('access "/files"', () {
      schedule(() {
        var handler = createStaticHandler(d.defaultRoot);

        return makeRequest(handler, '/files').then((response) {
          expect(response.statusCode, HttpStatus.NOT_FOUND);
        });
      });
    });

    test('access "/files/" dir', () {
      schedule(() {
        var handler = createStaticHandler(d.defaultRoot);

        return makeRequest(handler, '/files/').then((response) {
          expect(response.statusCode, HttpStatus.NOT_FOUND);
        });
      });
    });
  });

  group('default document specified', () {
    test('access "/index.html"', () {
      schedule(() {
        var handler =
            createStaticHandler(d.defaultRoot, defaultDocument: 'index.html');

        return makeRequest(handler, '/index.html').then((response) {
          expect(response.statusCode, HttpStatus.OK);
          expect(response.contentLength, 13);
          expect(response.readAsString(), completion('<html></html>'));
          expect(response.mimeType, 'text/html');
        });
      });
    });

    test('access "/"', () {
      schedule(() {
        var handler =
            createStaticHandler(d.defaultRoot, defaultDocument: 'index.html');

        return makeRequest(handler, '/').then((response) {
          expect(response.statusCode, HttpStatus.OK);
          expect(response.contentLength, 13);
          expect(response.readAsString(), completion('<html></html>'));
          expect(response.mimeType, 'text/html');
        });
      });
    });

    test('access "/files"', () {
      schedule(() {
        var handler =
            createStaticHandler(d.defaultRoot, defaultDocument: 'index.html');

        return makeRequest(handler, '/files').then((response) {
          expect(response.statusCode, HttpStatus.MOVED_PERMANENTLY);
          expect(response.headers,
              containsPair(HttpHeaders.LOCATION, 'http://localhost/files/'));
        });
      });
    });

    test('access "/files/" dir', () {
      schedule(() {
        var handler =
            createStaticHandler(d.defaultRoot, defaultDocument: 'index.html');

        return makeRequest(handler, '/files/').then((response) {
          expect(response.statusCode, HttpStatus.OK);
          expect(response.contentLength, 31);
          expect(response.readAsString(),
              completion('<html><body>files</body></html>'));
          expect(response.mimeType, 'text/html');
        });
      });
    });
  });
}
