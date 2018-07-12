// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart' as mime;
import 'package:path/path.dart' as p;
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test/test.dart';

import 'package:shelf_static/shelf_static.dart';
import 'test_util.dart';

void main() {
  setUp(() async {
    await d.file('index.html', '<html></html>').create();
    await d.file('root.txt', 'root txt').create();
    await d.file('random.unknown', 'no clue').create();

    var pngBytesContent =
        r"iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAABmJLR0QA/wD/AP+gvae"
        r"TAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH4AYRETkSXaxBzQAAAB1pVFh0Q2"
        r"9tbWVudAAAAAAAQ3JlYXRlZCB3aXRoIEdJTVBkLmUHAAAAbUlEQVQI1wXBvwpBYRwA0"
        r"HO/kjBKJmXRLWXxJ4PsnsMTeAEPILvNZrybF7B4A6XvQW6k+DkHwqgM1TnMpoEoDMtw"
        r"OJE7pB/VXmF3CdseucmjxaAruR41Pl9p/Gbyoq5B9FeL2OR7zJ+3aC/X8QdQCyIArPs"
        r"HkQAAAABJRU5ErkJggg==";

    var webpBytesContent =
        r"UklGRiQAAABXRUJQVlA4IBgAAAAwAQCdASoBAAEAAQAcJaQAA3AA/v3AgAA=";

    await d.dir('files', [
      d.file('test.txt', 'test txt content'),
      d.file('with space.txt', 'with space content'),
      d.file('header_bytes_test_image', base64Decode(pngBytesContent)),
      d.file('header_bytes_test_webp', base64Decode(webpBytesContent))
    ]).create();
  });

  test('access root file', () async {
    var handler = createStaticHandler(d.sandbox);

    var response = await makeRequest(handler, '/root.txt');
    expect(response.statusCode, HttpStatus.ok);
    expect(response.contentLength, 8);
    expect(response.readAsString(), completion('root txt'));
  });

  test('access root file with space', () async {
    var handler = createStaticHandler(d.sandbox);

    var response = await makeRequest(handler, '/files/with%20space.txt');
    expect(response.statusCode, HttpStatus.ok);
    expect(response.contentLength, 18);
    expect(response.readAsString(), completion('with space content'));
  });

  test('access root file with unencoded space', () async {
    var handler = createStaticHandler(d.sandbox);

    var response = await makeRequest(handler, '/files/with%20space.txt');
    expect(response.statusCode, HttpStatus.ok);
    expect(response.contentLength, 18);
    expect(response.readAsString(), completion('with space content'));
  });

  test('access file under directory', () async {
    var handler = createStaticHandler(d.sandbox);

    var response = await makeRequest(handler, '/files/test.txt');
    expect(response.statusCode, HttpStatus.ok);
    expect(response.contentLength, 16);
    expect(response.readAsString(), completion('test txt content'));
  });

  test('file not found', () async {
    var handler = createStaticHandler(d.sandbox);

    var response = await makeRequest(handler, '/not_here.txt');
    expect(response.statusCode, HttpStatus.notFound);
  });

  test('last modified', () async {
    var handler = createStaticHandler(d.sandbox);

    var rootPath = p.join(d.sandbox, 'root.txt');
    var modified = new File(rootPath).statSync().changed.toUtc();

    var response = await makeRequest(handler, '/root.txt');
    expect(response.lastModified, atSameTimeToSecond(modified));
  });

  group('if modified since', () {
    test('same as last modified', () async {
      var handler = createStaticHandler(d.sandbox);

      var rootPath = p.join(d.sandbox, 'root.txt');
      var modified = new File(rootPath).statSync().changed.toUtc();

      var headers = {
        HttpHeaders.ifModifiedSinceHeader: formatHttpDate(modified)
      };

      var response = await makeRequest(handler, '/root.txt', headers: headers);
      expect(response.statusCode, HttpStatus.notModified);
      expect(response.contentLength, 0);
    });

    test('before last modified', () async {
      var handler = createStaticHandler(d.sandbox);

      var rootPath = p.join(d.sandbox, 'root.txt');
      var modified = new File(rootPath).statSync().changed.toUtc();

      var headers = {
        HttpHeaders.ifModifiedSinceHeader:
            formatHttpDate(modified.subtract(const Duration(seconds: 1)))
      };

      var response = await makeRequest(handler, '/root.txt', headers: headers);
      expect(response.statusCode, HttpStatus.ok);
      expect(response.lastModified, atSameTimeToSecond(modified));
    });

    test('after last modified', () async {
      var handler = createStaticHandler(d.sandbox);

      var rootPath = p.join(d.sandbox, 'root.txt');
      var modified = new File(rootPath).statSync().changed.toUtc();

      var headers = {
        HttpHeaders.ifModifiedSinceHeader:
            formatHttpDate(modified.add(const Duration(seconds: 1)))
      };

      var response = await makeRequest(handler, '/root.txt', headers: headers);
      expect(response.statusCode, HttpStatus.notModified);
      expect(response.contentLength, 0);
    });
  });

  group('content type', () {
    test('root.txt should be text/plain', () async {
      var handler = createStaticHandler(d.sandbox);

      var response = await makeRequest(handler, '/root.txt');
      expect(response.mimeType, 'text/plain');
    });

    test('index.html should be text/html', () async {
      var handler = createStaticHandler(d.sandbox);

      var response = await makeRequest(handler, '/index.html');
      expect(response.mimeType, 'text/html');
    });

    test('random.unknown should be null', () async {
      var handler = createStaticHandler(d.sandbox);

      var response = await makeRequest(handler, '/random.unknown');
      expect(response.mimeType, isNull);
    });

    test('header_bytes_test_image should be image/png', () async {
      final handler =
          createStaticHandler(d.sandbox, useHeaderBytesForContentType: true);

      var response =
          await makeRequest(handler, '/files/header_bytes_test_image');
      expect(response.mimeType, "image/png");
    });

    test('header_bytes_test_webp should be image/webp', () async {
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
      final handler = createStaticHandler(d.sandbox,
          useHeaderBytesForContentType: true, contentTypeResolver: resolver);

      var response =
          await makeRequest(handler, '/files/header_bytes_test_webp');
      expect(response.mimeType, "image/webp");
    });
  });
}
