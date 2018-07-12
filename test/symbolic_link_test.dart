// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test/test.dart';

import 'package:shelf_static/shelf_static.dart';
import 'test_util.dart';

void main() {
  setUp(() async {
    await d.dir('originals', [
      d.file('index.html', '<html></html>'),
    ]).create();

    await d.dir('alt_root').create();

    var originalsDir = p.join(d.sandbox, 'originals');
    var originalsIndex = p.join(originalsDir, 'index.html');

    new Link(p.join(d.sandbox, 'link_index.html')).createSync(originalsIndex);

    new Link(p.join(d.sandbox, 'link_dir')).createSync(originalsDir);

    new Link(p.join(d.sandbox, 'alt_root', 'link_index.html'))
        .createSync(originalsIndex);

    new Link(p.join(d.sandbox, 'alt_root', 'link_dir'))
        .createSync(originalsDir);
  });

  group('access outside of root disabled', () {
    test('access real file', () async {
      var handler = createStaticHandler(d.sandbox);

      var response = await makeRequest(handler, '/originals/index.html');
      expect(response.statusCode, HttpStatus.ok);
      expect(response.contentLength, 13);
      expect(response.readAsString(), completion('<html></html>'));
    });

    group('links under root dir', () {
      test('access sym linked file in real dir', () async {
        var handler = createStaticHandler(d.sandbox);

        var response = await makeRequest(handler, '/link_index.html');
        expect(response.statusCode, HttpStatus.ok);
        expect(response.contentLength, 13);
        expect(response.readAsString(), completion('<html></html>'));
      });

      test('access file in sym linked dir', () async {
        var handler = createStaticHandler(d.sandbox);

        var response = await makeRequest(handler, '/link_dir/index.html');
        expect(response.statusCode, HttpStatus.ok);
        expect(response.contentLength, 13);
        expect(response.readAsString(), completion('<html></html>'));
      });
    });

    group('links not under root dir', () {
      test('access sym linked file in real dir', () async {
        var handler = createStaticHandler(p.join(d.sandbox, 'alt_root'));

        var response = await makeRequest(handler, '/link_index.html');
        expect(response.statusCode, HttpStatus.notFound);
      });

      test('access file in sym linked dir', () async {
        var handler = createStaticHandler(p.join(d.sandbox, 'alt_root'));

        var response = await makeRequest(handler, '/link_dir/index.html');
        expect(response.statusCode, HttpStatus.notFound);
      });
    });
  });

  group('access outside of root enabled', () {
    test('access real file', () async {
      var handler = createStaticHandler(d.sandbox, serveFilesOutsidePath: true);

      var response = await makeRequest(handler, '/originals/index.html');
      expect(response.statusCode, HttpStatus.ok);
      expect(response.contentLength, 13);
      expect(response.readAsString(), completion('<html></html>'));
    });

    group('links under root dir', () {
      test('access sym linked file in real dir', () async {
        var handler =
            createStaticHandler(d.sandbox, serveFilesOutsidePath: true);

        var response = await makeRequest(handler, '/link_index.html');
        expect(response.statusCode, HttpStatus.ok);
        expect(response.contentLength, 13);
        expect(response.readAsString(), completion('<html></html>'));
      });

      test('access file in sym linked dir', () async {
        var handler =
            createStaticHandler(d.sandbox, serveFilesOutsidePath: true);

        var response = await makeRequest(handler, '/link_dir/index.html');
        expect(response.statusCode, HttpStatus.ok);
        expect(response.contentLength, 13);
        expect(response.readAsString(), completion('<html></html>'));
      });
    });

    group('links not under root dir', () {
      test('access sym linked file in real dir', () async {
        var handler = createStaticHandler(p.join(d.sandbox, 'alt_root'),
            serveFilesOutsidePath: true);

        var response = await makeRequest(handler, '/link_index.html');
        expect(response.statusCode, HttpStatus.ok);
        expect(response.contentLength, 13);
        expect(response.readAsString(), completion('<html></html>'));
      });

      test('access file in sym linked dir', () async {
        var handler = createStaticHandler(p.join(d.sandbox, 'alt_root'),
            serveFilesOutsidePath: true);

        var response = await makeRequest(handler, '/link_dir/index.html');
        expect(response.statusCode, HttpStatus.ok);
        expect(response.contentLength, 13);
        expect(response.readAsString(), completion('<html></html>'));
      });
    });
  });
}
