// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';

String _getHeader(String sanitizedHeading) {
  return '''<!DOCTYPE html>
<html>
<head>
  <title>Directory listing for $sanitizedHeading</title>
  <style>
  html, body {
    margin: 0;
    padding: 0;
  }
  body {
    font-family: sans-serif;
  }
  h1 {
    background-color: #607D8B;
    box-shadow: 0 1px 4px 0 rgba(0, 0, 0, 0.37);
    color: white;
    font-size: 56px;
    font-weight: normal;
    line-height: 1.5;
    margin: 0;
    padding: 115px 30px 56px 30px;
    white-space: nowrap;
  }
  ul {
    list-style-type: none;
    margin: 0;
    padding: 0;
  }
  li {
    margin: 0;
    padding: 0;
  }
  a {
    color: #212121;
    text-decoration: none;
    display: block;
    font-size: 16px;
    height: 48px;
    line-height: 48px;
    padding-left: 16px;
    transition: background-color 200ms ease-in-out;
  }
  a:hover {
    background-color: #EEEEEE;
  }
  </style>
</head>
<body>
  <h1>$sanitizedHeading</h1>
  <ul>
''';
}

const String _trailer = '''  </ul>
</body>
</html>
''';

Response listDirectory(String fileSystemPath, String dirPath) {
  StreamController<List<int>> controller = new StreamController<List<int>>();
  Encoding encoding = new Utf8Codec();
  HtmlEscape sanitizer = const HtmlEscape();

  void add(String string) {
    controller.add(encoding.encode(string));
  }

  var heading = path.relative(dirPath, from: fileSystemPath);
  if (heading == '.') {
    heading = '/';
  } else {
    heading = '/$heading/';
  }

  add(_getHeader(sanitizer.convert(heading)));
  new Directory(dirPath).list().listen((FileSystemEntity entity) {
    String name = path.relative(entity.path, from: dirPath);
    if (entity is Directory) name += '/';
    String sanitizedName = sanitizer.convert(name);
    add('    <li><a href="$sanitizedName">$sanitizedName</a></li>\n');
  }, onDone: () {
    add(_trailer);
    controller.close();
  });
  return new Response.ok(controller.stream,
      encoding: encoding, headers: {HttpHeaders.CONTENT_TYPE: 'text/html'});
}
