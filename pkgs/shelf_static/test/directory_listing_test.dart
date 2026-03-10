// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_static/src/directory_listing.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'test_util.dart';

void main() {
  setUp(() async {
    await d.file('index.html', '<html></html>').create();
    await d.file('root.txt', 'root txt').create();
    await d.dir('files', [
      d.file('index.html', '<html><body>files</body></html>'),
      d.file('with space.txt', 'with space content'),
      d.file('file_1_kb.txt', 'a' * 1024),
      d.file('file_1.5_kb.txt', 'a' * 1536),
      d.file('file_with_<brackets>.txt', 'xss'),
      d.dir('empty subfolder', []),
    ]).create();
  });

  test('access "/"', () async {
    final handler = createStaticHandler(d.sandbox, listDirectories: true);

    final response = await makeRequest(handler, '/');
    expect(response.statusCode, HttpStatus.ok);
    expect(response.readAsString(), completes);
  });

  test('access "/files"', () async {
    final handler = createStaticHandler(d.sandbox, listDirectories: true);

    final response = await makeRequest(handler, '/files');
    expect(response.statusCode, HttpStatus.movedPermanently);
    expect(response.headers,
        containsPair(HttpHeaders.locationHeader, 'http://localhost/files/'));
  });

  test('access "/files/"', () async {
    final handler = createStaticHandler(d.sandbox, listDirectories: true);

    final response = await makeRequest(handler, '/files/');
    expect(response.statusCode, HttpStatus.ok);
    expect(response.readAsString(), completes);
  });

  test('access "/files/empty subfolder"', () async {
    final handler = createStaticHandler(d.sandbox, listDirectories: true);

    final response = await makeRequest(handler, '/files/empty subfolder');
    expect(response.statusCode, HttpStatus.movedPermanently);
    expect(
        response.headers,
        containsPair(HttpHeaders.locationHeader,
            'http://localhost/files/empty%20subfolder/'));
  });

  test('access "/files/empty subfolder/"', () async {
    final handler = createStaticHandler(d.sandbox, listDirectories: true);

    final response = await makeRequest(handler, '/files/empty subfolder/');
    expect(response.statusCode, HttpStatus.ok);
    expect(response.readAsString(), completes);
  });

  test('formats file sizes correctly', () async {
    final handler = createStaticHandler(d.sandbox, listDirectories: true);
    final response = await makeRequest(handler, '/files/');

    expect(response.statusCode, HttpStatus.ok);
    final html = await response.readAsString();

    // Verify perfectly round sizes drop the `.0` decimal for cleanliness.
    expect(html, contains('1 KB'));
    expect(html, isNot(contains('1.0 KB')));

    // Verify fractional sizes retain their decimal.
    expect(html, contains('1.5 KB'));
  });

  test('encodes URI components to prevent XSS', () async {
    final handler = createStaticHandler(d.sandbox, listDirectories: true);
    final response = await makeRequest(handler, '/files/');

    expect(response.statusCode, HttpStatus.ok);
    final html = await response.readAsString();

    // Verify that potentially malicious characters like `<` and `>` in
    // filenames are percent-encoded in the anchor `href` attribute.
    expect(html, contains('href="./file_with_%3Cbrackets%3E.txt"'));

    // Verify that the displayed text for the filename is properly
    // HTML-escaped to safely render without executing.
    expect(html, contains('file_with_&lt;brackets&gt;.txt'));
  });

  test('blocks directory traversal outside of root', () async {
    final response = await listDirectory(d.sandbox, p.join(d.sandbox, '..'));
    expect(response.statusCode, HttpStatus.notFound);
  });

  test('blocks directory traversal via symlinks in directory listings',
      () async {
    // Create a symlink pointing outside the `files` directory but within
    // sandbox.
    // The handler root is `files`, so `outside.txt` is outside root.
    await d.dir('outside', [d.file('outside.txt', 'contents')]).create();

    // We serve from d.sandbox/files
    final filesDir = p.join(d.sandbox, 'files');

    // Create symlink inside `files` pointing to `outside`
    final linkPath = p.join(filesDir, 'symlink');
    Link(linkPath).createSync(p.join(d.sandbox, 'outside'));

    final response = await listDirectory(filesDir, filesDir);
    expect(response.statusCode, HttpStatus.ok);

    final html = await response.readAsString();
    // Symlink pointing outside should not be listed if
    // serveFilesOutsidePath is false
    expect(html, isNot(contains('symlink')));
  });
}
