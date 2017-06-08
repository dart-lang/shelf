// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart' as mime;
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

    d.file('index.html', '<html></html>').create();
    d.file('root.txt', 'root txt').create();
    d.file('random.unknown', 'no clue').create();

    var pngBytesContent =
        r"iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAABmJLR0QA/wD/AP+gvae"
        r"TAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH4AYRETkSXaxBzQAAAB1pVFh0Q2"
        r"9tbWVudAAAAAAAQ3JlYXRlZCB3aXRoIEdJTVBkLmUHAAAAbUlEQVQI1wXBvwpBYRwA0"
        r"HO/kjBKJmXRLWXxJ4PsnsMTeAEPILvNZrybF7B4A6XvQW6k+DkHwqgM1TnMpoEoDMtw"
        r"OJE7pB/VXmF3CdseucmjxaAruR41Pl9p/Gbyoq5B9FeL2OR7zJ+3aC/X8QdQCyIArPs"
        r"HkQAAAABJRU5ErkJggg==";

    var webpBytesContent =
        r"UklGRiQAAABXRUJQVlA4IBgAAAAwAQCdASoBAAEAAQAcJaQAA3AA/v3AgAA=";

    d.dir('files', [
      d.file('test.txt', 'test txt content'),
      d.file('with space.txt', 'with space content'),
      d.binaryFile('header_bytes_test_image', BASE64.decode(pngBytesContent)),
      d.binaryFile('header_bytes_test_webp', BASE64.decode(webpBytesContent))
    ]).create();

    currentSchedule.onComplete.schedule(() {
      d.defaultRoot = null;
      return tempDir.delete(recursive: true);
    });
  });

  test('access root file', () {
    schedule(() {
      var handler = createStaticHandler(d.defaultRoot);

      return makeRequest(handler, '/root.txt').then((response) {
        expect(response.statusCode, HttpStatus.OK);
        expect(response.contentLength, 8);
        expect(response.readAsString(), completion('root txt'));
      });
    });
  });

  test('access root file with space', () {
    schedule(() {
      var handler = createStaticHandler(d.defaultRoot);

      return makeRequest(handler, '/files/with%20space.txt').then((response) {
        expect(response.statusCode, HttpStatus.OK);
        expect(response.contentLength, 18);
        expect(response.readAsString(), completion('with space content'));
      });
    });
  });

  test('access root file with unencoded space', () {
    schedule(() {
      var handler = createStaticHandler(d.defaultRoot);

      return makeRequest(handler, '/files/with%20space.txt').then((response) {
        expect(response.statusCode, HttpStatus.OK);
        expect(response.contentLength, 18);
        expect(response.readAsString(), completion('with space content'));
      });
    });
  });

  test('access file under directory', () {
    schedule(() {
      var handler = createStaticHandler(d.defaultRoot);

      return makeRequest(handler, '/files/test.txt').then((response) {
        expect(response.statusCode, HttpStatus.OK);
        expect(response.contentLength, 16);
        expect(response.readAsString(), completion('test txt content'));
      });
    });
  });

  test('file not found', () {
    schedule(() {
      var handler = createStaticHandler(d.defaultRoot);

      return makeRequest(handler, '/not_here.txt').then((response) {
        expect(response.statusCode, HttpStatus.NOT_FOUND);
      });
    });
  });

  test('last modified', () {
    schedule(() {
      var handler = createStaticHandler(d.defaultRoot);

      var rootPath = p.join(d.defaultRoot, 'root.txt');
      var modified = new File(rootPath).statSync().changed.toUtc();

      return makeRequest(handler, '/root.txt').then((response) {
        expect(response.lastModified, atSameTimeToSecond(modified));
      });
    });
  });

  group('if modified since', () {
    test('same as last modified', () {
      schedule(() {
        var handler = createStaticHandler(d.defaultRoot);

        var rootPath = p.join(d.defaultRoot, 'root.txt');
        var modified = new File(rootPath).statSync().changed.toUtc();

        var headers = {HttpHeaders.IF_MODIFIED_SINCE: formatHttpDate(modified)};

        return makeRequest(handler, '/root.txt', headers: headers)
            .then((response) {
          expect(response.statusCode, HttpStatus.NOT_MODIFIED);
          expect(response.contentLength, 0);
        });
      });
    });

    test('before last modified', () {
      schedule(() {
        var handler = createStaticHandler(d.defaultRoot);

        var rootPath = p.join(d.defaultRoot, 'root.txt');
        var modified = new File(rootPath).statSync().changed.toUtc();

        var headers = {
          HttpHeaders.IF_MODIFIED_SINCE:
              formatHttpDate(modified.subtract(const Duration(seconds: 1)))
        };

        return makeRequest(handler, '/root.txt', headers: headers)
            .then((response) {
          expect(response.statusCode, HttpStatus.OK);
          expect(response.lastModified, atSameTimeToSecond(modified));
        });
      });
    });

    test('after last modified', () {
      schedule(() {
        var handler = createStaticHandler(d.defaultRoot);

        var rootPath = p.join(d.defaultRoot, 'root.txt');
        var modified = new File(rootPath).statSync().changed.toUtc();

        var headers = {
          HttpHeaders.IF_MODIFIED_SINCE:
              formatHttpDate(modified.add(const Duration(seconds: 1)))
        };

        return makeRequest(handler, '/root.txt', headers: headers)
            .then((response) {
          expect(response.statusCode, HttpStatus.NOT_MODIFIED);
          expect(response.contentLength, 0);
        });
      });
    });
  });

  group('content type', () {
    test('root.txt should be text/plain', () {
      schedule(() {
        var handler = createStaticHandler(d.defaultRoot);

        return makeRequest(handler, '/root.txt').then((response) {
          expect(response.mimeType, 'text/plain');
        });
      });
    });

    test('index.html should be text/html', () {
      schedule(() {
        var handler = createStaticHandler(d.defaultRoot);

        return makeRequest(handler, '/index.html').then((response) {
          expect(response.mimeType, 'text/html');
        });
      });
    });

    test('random.unknown should be null', () {
      schedule(() {
        var handler = createStaticHandler(d.defaultRoot);

        return makeRequest(handler, '/random.unknown').then((response) {
          expect(response.mimeType, isNull);
        });
      });
    });

    test('header_bytes_test_image should be image/png', () {
      schedule(() {
        final dynamic handler = createStaticHandler(d.defaultRoot,
            useHeaderBytesForContentType: true);

        return makeRequest(handler, '/files/header_bytes_test_image')
            .then((response) {
          expect(response.mimeType, "image/png");
        });
      });
    });

    test('header_bytes_test_webp should be image/webp', () {
      schedule(() {
        final mime.MimeTypeResolver resolver = new mime.MimeTypeResolver();
        resolver.addMagicNumber(
            <int>[
              0x52, 0x49, 0x46, 0x46, 0x00, 0x00, //
              0x00, 0x00, 0x57, 0x45, 0x42, 0x50
            ],
            "image/webp",
            mask: <int>[
              0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, //
              0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF
            ]);
        final dynamic handler = createStaticHandler(d.defaultRoot,
            useHeaderBytesForContentType: true, contentTypeResolver: resolver);

        return makeRequest(handler, '/files/header_bytes_test_webp')
            .then((response) {
          expect(response.mimeType, "image/webp");
        });
      });
    });
  });
}
