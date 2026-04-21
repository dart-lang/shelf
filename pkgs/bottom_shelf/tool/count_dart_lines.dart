#!/usr/bin/env dart
// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

Future<void> main(List<String> arguments) async {
  final dirPath = arguments.isNotEmpty ? arguments.first : '.';
  final dir = Directory(dirPath);

  if (!await dir.exists()) {
    print('Directory not found: $dirPath');
    exitCode = 64; // Bad usage
    return;
  }

  var totalFiles = 0;
  var totalLines = 0;
  var totalBlankLines = 0;
  var totalCommentLines = 0;

  await for (final entity in dir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      totalFiles++;
      final lines = await entity.readAsLines();
      for (final line in lines) {
        totalLines++;
        final trimmed = line.trimLeft();
        if (trimmed.isEmpty) {
          totalBlankLines++;
        } else if (trimmed.startsWith('//')) {
          totalCommentLines++;
        }
      }
    }
  }

  final codeLines = totalLines - totalBlankLines - totalCommentLines;

  print('Dart Line Counter');
  print('-----------------');
  print('Directory: $dirPath');
  print('Files found: $totalFiles');
  print('Total lines: $totalLines');
  print('Blank lines: $totalBlankLines');
  print('Comment lines: $totalCommentLines');
  print('Code lines: $codeLines');
}
