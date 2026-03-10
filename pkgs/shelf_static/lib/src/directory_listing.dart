// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';

String _getHeader(String sanitizedHeading) => '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Index of $sanitizedHeading</title>
  <style>
  html, body {
    margin: 0;
    padding: 0;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
    background-color: #f9fafb;
    color: #111827;
  }
  .container {
    max-width: 1024px;
    margin: 0 auto;
    padding: 2rem;
  }
  h1 {
    font-size: 1.5rem;
    font-weight: 500;
    margin-bottom: 1.5rem;
    padding-bottom: 0.5rem;
    border-bottom: 1px solid #e5e7eb;
    word-break: break-all;
  }
  table {
    width: 100%;
    border-collapse: collapse;
    background: white;
    border-radius: 8px;
    overflow: hidden;
    box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px 0 rgba(0, 0, 0, 0.06);
  }
  th, td {
    padding: 0.75rem 1rem;
    text-align: left;
    border-bottom: 1px solid #e5e7eb;
  }
  th {
    background-color: #f3f4f6;
    font-weight: 600;
    font-size: 0.875rem;
    color: #4b5563;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }
  tr:last-child td {
    border-bottom: none;
  }
  tr:hover {
    background-color: #f9fafb;
  }
  a {
    color: #2563eb;
    text-decoration: none;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }
  a:hover {
    text-decoration: underline;
  }
  .icon {
    width: 1.25rem;
    height: 1.25rem;
    flex-shrink: 0;
  }
  .icon-dir {
    color: #93c5fd;
    fill: currentColor;
  }
  .icon-file {
    color: #9ca3af;
    fill: none;
    stroke: currentColor;
    stroke-width: 2;
    stroke-linecap: round;
    stroke-linejoin: round;
  }
  .size, .date {
    color: #6b7280;
    font-size: 0.875rem;
    white-space: nowrap;
  }
  .size {
    text-align: right;
  }
  th.size {
    text-align: right;
  }
  @media (max-width: 640px) {
    .date {
      display: none;
    }
  }
  </style>
</head>
<body>
  <div class="container">
    <h1>Index of $sanitizedHeading</h1>
    <table>
      <thead>
        <tr>
          <th>Name</th>
          <th class="date">Last Modified</th>
          <th class="size">Size</th>
        </tr>
      </thead>
      <tbody>
''';

const String _trailer = '''      </tbody>
    </table>
  </div>
</body>
</html>
''';

const String _dirIcon =
    '''<svg class="icon icon-dir" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path d="M2 6a2 2 0 012-2h5l2 2h5a2 2 0 012 2v6a2 2 0 01-2 2H4a2 2 0 01-2-2V6z"></path></svg>''';
const String _fileIcon =
    '''<svg class="icon icon-file" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z"></path></svg>''';

String _formatSize(int bytes) {
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;

  String format(double value) =>
      value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');

  if (bytes < kb) return '$bytes B';
  if (bytes < mb) return '${format(bytes / kb)} KB';
  if (bytes < gb) return '${format(bytes / mb)} MB';
  return '${format(bytes / gb)} GB';
}

String _formatDate(DateTime date) {
  final y = date.year;
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  final h = date.hour.toString().padLeft(2, '0');
  final min = date.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $h:$min';
}

Future<Response> listDirectory(String fileSystemPath, String dirPath,
    {bool serveFilesOutsidePath = false}) async {
  if (!serveFilesOutsidePath) {
    var resolvedPath = dirPath;
    try {
      resolvedPath = await Directory(dirPath).resolveSymbolicLinks();
    } catch (_) {
      // Ignore errors resolving symlinks
    }

    if (!path.isWithin(fileSystemPath, resolvedPath) &&
        !path.equals(fileSystemPath, resolvedPath)) {
      return Response.notFound('Not Found');
    }
  }

  if (!path.isWithin(fileSystemPath, dirPath) &&
      !path.equals(fileSystemPath, dirPath)) {
    return Response.notFound('Not Found');
  }

  const sanitizer = HtmlEscape();

  var heading = path.relative(dirPath, from: fileSystemPath);
  if (heading == '.') {
    heading = '/';
  } else {
    heading = '/$heading/';
  }

  final buffer = StringBuffer();
  buffer.write(_getHeader(sanitizer.convert(heading)));

  if (heading != '/') {
    buffer.write('''
        <tr>
          <td><a href="../">$_dirIcon ..</a></td>
          <td class="date">-</td>
          <td class="size">-</td>
        </tr>
''');
  }

  final entities = await Directory(dirPath).list().toList();
  entities.sort((e1, e2) {
    if (e1 is Directory && e2 is! Directory) return -1;
    if (e1 is! Directory && e2 is Directory) return 1;
    return e1.path.compareTo(e2.path);
  });

  final entitiesWithStats = (await Future.wait(entities.map((e) async {
    try {
      if (!serveFilesOutsidePath) {
        final resolvedPath = await e.resolveSymbolicLinks();
        if (!path.isWithin(fileSystemPath, resolvedPath) &&
            !path.equals(fileSystemPath, resolvedPath)) {
          return null;
        }
      }
      return (e, await e.stat());
    } catch (_) {
      return (e, null);
    }
  })))
      .whereType<(FileSystemEntity, FileStat?)>()
      .toList();

  for (final (entity, stat) in entitiesWithStats) {
    final isDir = entity is Directory;
    var name = path.relative(entity.path, from: dirPath);
    if (isDir) name += '/';
    final sanitizedName = sanitizer.convert(name);

    var sizeStr = '-';
    var dateStr = '-';

    if (stat != null) {
      if (!isDir) sizeStr = _formatSize(stat.size);
      dateStr = _formatDate(stat.modified);
    }

    final icon = isDir ? _dirIcon : _fileIcon;
    final encodedName = Uri.encodeComponent(name).replaceAll('%2F', '/');

    buffer.write('''
        <tr>
          <td><a href="./$encodedName">$icon $sanitizedName</a></td>
          <td class="date">$dateStr</td>
          <td class="size">$sizeStr</td>
        </tr>
''');
  }

  buffer.write(_trailer);

  return Response.ok(
    buffer.toString(),
    encoding: utf8,
    headers: {HttpHeaders.contentTypeHeader: 'text/html'},
  );
}
