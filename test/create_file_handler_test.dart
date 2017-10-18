// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
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
  var tempDir;
  setUp(() {
    schedule(() async {
      tempDir =
          (await Directory.systemTemp.createTemp('shelf_static-test-')).path;
      d.defaultRoot = tempDir;
    });

    d.file('file.txt', 'contents').create();
    d.file('random.unknown', 'no clue').create();

    currentSchedule.onComplete.schedule(() async {
      d.defaultRoot = null;
      await new Directory(tempDir).delete(recursive: true);
    });
  });

  test('serves the file contents', () {
    schedule(() async {
      var handler = createFileHandler(p.join(tempDir, 'file.txt'));
      var response = await makeRequest(handler, '/file.txt');
      expect(response.statusCode, equals(HttpStatus.OK));
      expect(response.contentLength, equals(8));
      expect(response.readAsString(), completion(equals('contents')));
    });
  });

  test('serves a 404 for a non-matching URL', () {
    schedule(() async {
      var handler = createFileHandler(p.join(tempDir, 'file.txt'));
      var response = await makeRequest(handler, '/foo/file.txt');
      expect(response.statusCode, equals(HttpStatus.NOT_FOUND));
    });
  });

  test('serves the file contents under a custom URL', () {
    schedule(() async {
      var handler =
          createFileHandler(p.join(tempDir, 'file.txt'), url: 'foo/bar');
      var response = await makeRequest(handler, '/foo/bar');
      expect(response.statusCode, equals(HttpStatus.OK));
      expect(response.contentLength, equals(8));
      expect(response.readAsString(), completion(equals('contents')));
    });
  });

  test("serves a 404 if the custom URL isn't matched", () {
    schedule(() async {
      var handler =
          createFileHandler(p.join(tempDir, 'file.txt'), url: 'foo/bar');
      var response = await makeRequest(handler, '/file.txt');
      expect(response.statusCode, equals(HttpStatus.NOT_FOUND));
    });
  });

  group('the content type header', () {
    test('is inferred from the file path', () {
      schedule(() async {
        var handler = createFileHandler(p.join(tempDir, 'file.txt'));
        var response = await makeRequest(handler, '/file.txt');
        expect(response.statusCode, equals(HttpStatus.OK));
        expect(response.mimeType, equals('text/plain'));
      });
    });

    test("is omitted if it can't be inferred", () {
      schedule(() async {
        var handler = createFileHandler(p.join(tempDir, 'random.unknown'));
        var response = await makeRequest(handler, '/random.unknown');
        expect(response.statusCode, equals(HttpStatus.OK));
        expect(response.mimeType, isNull);
      });
    });

    test('comes from the contentType parameter', () {
      schedule(() async {
        var handler = createFileHandler(p.join(tempDir, 'file.txt'),
            contentType: 'something/weird');
        var response = await makeRequest(handler, '/file.txt');
        expect(response.statusCode, equals(HttpStatus.OK));
        expect(response.mimeType, equals('something/weird'));
      });
    });
  });

  group('throws an ArgumentError for', () {
    test("a file that doesn't exist", () {
      expect(() => createFileHandler(p.join(tempDir, 'nothing.txt')),
          throwsArgumentError);
    });

    test("an absolute URL", () {
      expect(
          () => createFileHandler(p.join(tempDir, 'nothing.txt'),
              url: '/foo/bar'),
          throwsArgumentError);
    });
  });
}
