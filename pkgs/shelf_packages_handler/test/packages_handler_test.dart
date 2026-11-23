// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_packages_handler/shelf_packages_handler.dart';
import 'package:test/test.dart';

void main() {
  late String dir;
  setUp(() {
    dir = Directory.systemTemp
        .createTempSync('shelf_packages_handler_test')
        .path;
    Directory(dir).createSync();
    Directory('$dir/foo').createSync();
    File(
      '$dir/foo/foo.dart',
    ).writeAsStringSync("void main() => print('in foo');");
  });

  tearDown(() {
    Directory(dir).deleteSync(recursive: true);
  });

  group('packagesHandler', () {
    test('defaults to the current method of package resolution', () async {
      final handler = packagesHandler();
      final request = Request(
        'GET',
        Uri.parse(
          'http://example.com/shelf_packages_handler/'
          'shelf_packages_handler.dart',
        ),
      );
      final response = await handler(request);
      expect(response.statusCode, equals(200));
      expect(
        await response.readAsString(),
        contains('Handler packagesHandler'),
      );
    });

    group('with a package map', () {
      late Handler handler;

      setUp(() {
        handler = packagesHandler(packageMap: {'foo': Uri.file('$dir/foo/')});
      });

      test('looks up a real file', () async {
        final request = Request(
          'GET',
          Uri.parse('http://example.com/foo/foo.dart'),
        );
        final response = await handler(request);
        expect(response.statusCode, equals(200));
        expect(await response.readAsString(), contains('in foo'));
      });

      test('404s for a nonexistent package', () async {
        final request = Request(
          'GET',
          Uri.parse('http://example.com/bar/foo.dart'),
        );
        final response = await handler(request);
        expect(response.statusCode, equals(404));
        expect(
          await response.readAsString(),
          contains('Package bar not found'),
        );
      });

      test('404s for a nonexistent file', () async {
        final request = Request(
          'GET',
          Uri.parse('http://example.com/foo/bar.dart'),
        );
        final response = await handler(request);
        expect(response.statusCode, equals(404));
      });

      test('404s for an empty path', () async {
        final request = Request('GET', Uri.parse('http://example.com/'));
        final response = await handler(request);
        expect(response.statusCode, equals(404));
      });

      test('supports dotted package names', () async {
        final dottedHandler = packagesHandler(
          packageMap: {'a.b.c': Uri.file('$dir/foo/')},
        );
        final request = Request(
          'GET',
          Uri.parse('http://example.com/a.b.c/foo.dart'),
        );
        final response = await dottedHandler(request);
        expect(response.statusCode, equals(200));
        expect(await response.readAsString(), contains('in foo'));
      });
    });
  });

  group('packagesDirHandler', () {
    test('supports a directory at the root of the URL', () async {
      final handler = packagesDirHandler();
      final request = Request(
        'GET',
        Uri.parse(
          'http://example.com/packages/shelf_packages_handler/'
          'shelf_packages_handler.dart',
        ),
      );
      final response = await handler(request);
      expect(response.statusCode, equals(200));
      expect(
        await response.readAsString(),
        contains('Handler packagesHandler'),
      );
    });

    test('supports a directory deep in the URL', () async {
      final handler = packagesDirHandler();
      final request = Request(
        'GET',
        Uri.parse(
          'http://example.com/foo/bar/very/deep/packages/'
          'shelf_packages_handler/shelf_packages_handler.dart',
        ),
      );
      final response = await handler(request);
      expect(response.statusCode, equals(200));
      expect(
        await response.readAsString(),
        contains('Handler packagesHandler'),
      );
    });

    test('404s for a URL without a packages directory', () async {
      final handler = packagesDirHandler();
      final request = Request(
        'GET',
        Uri.parse(
          'http://example.com/shelf_packages_handler/'
          'shelf_packages_handler.dart',
        ),
      );
      final response = await handler(request);
      expect(response.statusCode, equals(404));
    });

    test('404s for bare /packages and /packages/', () async {
      final handler = packagesDirHandler();
      for (final url in [
        'http://example.com/packages',
        'http://example.com/packages/',
      ]) {
        final response = await handler(Request('GET', Uri.parse(url)));
        expect(response.statusCode, equals(404), reason: url);
      }
    });

    test('404s for a non-existent file within a packages directory', () async {
      final handler = packagesDirHandler();
      final request = Request(
        'GET',
        Uri.parse(
          'http://example.com/packages/shelf_packages_handler/'
          'non_existent.dart',
        ),
      );
      final response = await handler(request);
      expect(response.statusCode, equals(404));
    });
  });

  group('path containment and symlinks over HTTP', () {
    late File secretFile;
    late HttpServer server;

    setUp(() async {
      Directory('$dir/outside/nested').createSync(recursive: true);
      secretFile = File('$dir/outside/secret.txt')
        ..writeAsStringSync('top secret');
      File(
        '$dir/outside/nested/linked.dart',
      ).writeAsStringSync("const linked = 'ok';");
      Directory('$dir/foo/sub/deep').createSync(recursive: true);

      if (!Platform.isWindows) {
        Link('$dir/foo/symlink.dart').createSync('$dir/outside/secret.txt');
        Link('$dir/foo/sub/deep/linked_dir').createSync('$dir/outside/nested');
      }

      server = await shelf_io.serve(
        packagesDirHandler(packageMap: {'foo': Uri.file('$dir/foo/')}),
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

    test(
      'follows symlinks inside package directories pointing outside',
      () async {
        final fileResp = await rawGet('/packages/foo/symlink.dart');
        expect(fileResp.status, equals(200));
        expect(fileResp.body, equals('top secret'));

        final dirResp = await rawGet(
          '/packages/foo/sub/deep/linked_dir/linked.dart',
        );
        expect(dirResp.status, equals(200));
        expect(dirResp.body, contains("const linked = 'ok'"));
      },
      testOn: '!windows',
    );

    test('blocks encoded absolute path segment', () async {
      final encoded = Uri.encodeComponent(secretFile.path);
      final response = await rawGet('/packages/foo/$encoded');
      expect(response.status, equals(404));
      expect(response.body, isNot(contains('top secret')));
    });

    for (final path in [
      '/packages/foo/..%2Foutside%2Fsecret.txt',
      '/packages/foo/..%2foutside%2fsecret.txt',
      '/packages/foo/sub/..%2F..%2Foutside%2Fsecret.txt',
      '/packages/foo/..%5Coutside%5Csecret.txt',
      '/packages/foo/foo.dart%00.txt',
      '/packages/foo/foo.dart::%24DATA',
      '/packages/foo/C:secret.txt',
      '/packages/foo%2F..%2Foutside/secret.txt',
      '/packages/..%2Foutside/secret.txt',
    ]) {
      test('blocks traversal request $path', () async {
        final response = await rawGet(path);
        expect(response.status, equals(404));
        expect(response.body, isNot(contains('top secret')));
      });
    }

    test('blocks double-slash absolute path after package name', () async {
      final rawSuffix = secretFile.path.startsWith('/')
          ? secretFile.path
          : '/${secretFile.path}';
      final response = await rawGet('/packages/foo/$rawSuffix');
      expect(response.status, equals(404));
      expect(response.body, isNot(contains('top secret')));
    });

    test('blocks encoded slash in isolate-resolved package name', () async {
      final handler = packagesDirHandler();
      final request = Request(
        'GET',
        Uri.parse(
          'http://example.com/packages/shelf_packages_handler%2Fsrc/'
          'package_config_handler.dart',
        ),
      );
      final response = await handler(request);
      expect(response.statusCode, equals(404));
    });

    test(
      'blocks climbing out of a symlinked subdirectory via encoded slashes',
      () async {
        final response = await rawGet(
          '/packages/foo/sub/deep/linked_dir/..%2Fsecret.txt',
        );
        expect(response.status, equals(404));
        expect(response.body, isNot(contains('top secret')));
      },
      testOn: '!windows',
    );
  });
}
