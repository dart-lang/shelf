// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'test_util.dart';

const _skipSymlinksOnWindows = {
  'windows': Skip('Skip tests for sym-linked files on Windows'),
};

void main() {
  setUp(() async {
    await d.dir('originals', [d.file('index.html', '<html></html>')]).create();

    await d.dir('alt_root').create();

    final originalsDir = p.join(d.sandbox, 'originals');
    final originalsIndex = p.join(originalsDir, 'index.html');

    Link(p.join(d.sandbox, 'link_index.html')).createSync(originalsIndex);

    Link(p.join(d.sandbox, 'link_dir')).createSync(originalsDir);

    Link(
      p.join(d.sandbox, 'alt_root', 'link_index.html'),
    ).createSync(originalsIndex);

    Link(p.join(d.sandbox, 'alt_root', 'link_dir')).createSync(originalsDir);
  });

  group('access outside of root disabled', () {
    test('access real file', () async {
      final handler = createStaticHandler(d.sandbox);

      final response = await makeRequest(handler, '/originals/index.html');
      expect(response.statusCode, HttpStatus.ok);
      expect(response.contentLength, 13);
      expect(response.readAsString(), completion('<html></html>'));
    });

    group('links under root dir', () {
      test('access sym linked file in real dir', () async {
        final handler = createStaticHandler(d.sandbox);

        final response = await makeRequest(handler, '/link_index.html');
        expect(response.statusCode, HttpStatus.ok);
        expect(response.contentLength, 13);
        expect(response.readAsString(), completion('<html></html>'));
      }, onPlatform: _skipSymlinksOnWindows);

      test('access file in sym linked dir', () async {
        final handler = createStaticHandler(d.sandbox);

        final response = await makeRequest(handler, '/link_dir/index.html');
        expect(response.statusCode, HttpStatus.ok);
        expect(response.contentLength, 13);
        expect(response.readAsString(), completion('<html></html>'));
      });
    });

    group('links not under root dir', () {
      test('access sym linked file in real dir', () async {
        final handler = createStaticHandler(p.join(d.sandbox, 'alt_root'));

        final response = await makeRequest(handler, '/link_index.html');
        expect(response.statusCode, HttpStatus.notFound);
      });

      test('access file in sym linked dir', () async {
        final handler = createStaticHandler(p.join(d.sandbox, 'alt_root'));

        final response = await makeRequest(handler, '/link_dir/index.html');
        expect(response.statusCode, HttpStatus.notFound);
      });
    });
  });

  group('access outside of root enabled', () {
    test('access real file', () async {
      final handler = createStaticHandler(
        d.sandbox,
        serveFilesOutsidePath: true,
      );

      final response = await makeRequest(handler, '/originals/index.html');
      expect(response.statusCode, HttpStatus.ok);
      expect(response.contentLength, 13);
      expect(response.readAsString(), completion('<html></html>'));
    });

    group('links under root dir', () {
      test('access sym linked file in real dir', () async {
        final handler = createStaticHandler(
          d.sandbox,
          serveFilesOutsidePath: true,
        );

        final response = await makeRequest(handler, '/link_index.html');
        expect(response.statusCode, HttpStatus.ok);
        expect(response.contentLength, 13);
        expect(response.readAsString(), completion('<html></html>'));
      }, onPlatform: _skipSymlinksOnWindows);

      test('access file in sym linked dir', () async {
        final handler = createStaticHandler(
          d.sandbox,
          serveFilesOutsidePath: true,
        );

        final response = await makeRequest(handler, '/link_dir/index.html');
        expect(response.statusCode, HttpStatus.ok);
        expect(response.contentLength, 13);
        expect(response.readAsString(), completion('<html></html>'));
      });
    });

    group('links not under root dir', () {
      test('access sym linked file in real dir', () async {
        final handler = createStaticHandler(
          p.join(d.sandbox, 'alt_root'),
          serveFilesOutsidePath: true,
        );

        final response = await makeRequest(handler, '/link_index.html');
        expect(response.statusCode, HttpStatus.ok);
        expect(response.contentLength, 13);
        expect(response.readAsString(), completion('<html></html>'));
      }, onPlatform: _skipSymlinksOnWindows);

      test('access file in sym linked dir', () async {
        final handler = createStaticHandler(
          p.join(d.sandbox, 'alt_root'),
          serveFilesOutsidePath: true,
        );

        final response = await makeRequest(handler, '/link_dir/index.html');
        expect(response.statusCode, HttpStatus.ok);
        expect(response.contentLength, 13);
        expect(response.readAsString(), completion('<html></html>'));
      });
    });

    group('path traversal is rejected over HTTP', () {
      late HttpServer server;

      setUp(() async {
        await d.dir('alt_root', [
          d.dir('sub', [d.dir('deep', [])]),
        ]).create();
        await d.dir('originals', [
          d.dir('nested', [d.file('nested.txt', 'nested')]),
        ]).create();
        if (!Platform.isWindows) {
          Link(
            p.join(d.sandbox, 'alt_root', 'sub', 'deep', 'link_nested'),
          ).createSync(p.join(d.sandbox, 'originals', 'nested'));
        }
        server = await shelf_io.serve(
          createStaticHandler(
            p.join(d.sandbox, 'alt_root'),
            serveFilesOutsidePath: true,
          ),
          InternetAddress.loopbackIPv4,
          0,
        );
      });

      tearDown(() => server.close(force: true));

      Future<({int status, String body})> rawGet(String path) async {
        final socket = await Socket.connect(server.address, server.port);
        socket.write(
          'GET $path HTTP/1.1\r\n'
          'Host: localhost\r\n'
          'Connection: close\r\n'
          '\r\n',
        );
        final response = await utf8.decoder.bind(socket).join();
        socket.destroy();
        final statusLine = response.substring(0, response.indexOf('\r\n'));
        final body = response.substring(response.indexOf('\r\n\r\n') + 4);
        return (status: int.parse(statusLine.split(' ')[1]), body: body);
      }

      for (final path in [
        '/../originals/index.html',
        '/%2E%2E/originals/index.html',
        '/..%2Foriginals%2Findex.html',
        '/..%2foriginals%2findex.html',
        '/sub/..%2F..%2Foriginals%2Findex.html',
        '/sub/%2E%2E%2F%2E%2E%2Foriginals%2Findex.html',
        '/..%5Coriginals%5Cindex.html',
        '/link_dir%2Findex.html',
        '/link_index.html%00.txt',
        '/link_index.html::%24DATA',
        '/C:index.html',
        '//originals/index.html',
      ]) {
        test(path, () async {
          final response = await rawGet(path);
          expect(response.status, HttpStatus.notFound);
          expect(response.body, isNot(contains('<html>')));
        });
      }

      test('with an encoded absolute path segment', () async {
        final outsidePath = p.join(d.sandbox, 'originals', 'index.html');
        final response = await rawGet('/${Uri.encodeComponent(outsidePath)}');
        expect(response.status, HttpStatus.notFound);
        expect(response.body, isNot(contains('<html>')));
      });

      test('with a double-slash absolute path', () async {
        final outsidePath = p.join(d.sandbox, 'originals', 'index.html');
        final rawPath = outsidePath.startsWith('/')
            ? '/$outsidePath'
            : '//$outsidePath';
        final response = await rawGet(rawPath);
        expect(response.status, HttpStatus.notFound);
        expect(response.body, isNot(contains('<html>')));
      });

      test(
        'climbing out of a symlinked subdirectory via encoded slashes',
        () async {
          // A naive lexical normalize check on `sub/deep/link_nested/..`
          // would think the path stayed within `alt_root`, while the OS
          // resolves `link_nested` first and climbs into `originals/`.
          final valid = await rawGet('/sub/deep/link_nested/nested.txt');
          expect(valid.status, HttpStatus.ok);
          expect(valid.body, 'nested');

          final escape = await rawGet('/sub/deep/link_nested/..%2Findex.html');
          expect(escape.status, HttpStatus.notFound);
          expect(escape.body, isNot(contains('<html>')));
        },
        onPlatform: _skipSymlinksOnWindows,
      );
    });
  });
}
