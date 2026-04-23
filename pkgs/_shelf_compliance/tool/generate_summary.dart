// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:_shelf_compliance/src/generate_summary.dart';

void main(List<String> args) {
  if (args.length < 2) {
    print('Usage: dart generate_summary.dart <json_directory> <markdown_file>');
    exit(1);
  }

  final jsonDir = Directory(args[0]);
  final mdFile = File(args[1]);

  if (!jsonDir.existsSync()) {
    print('Error: Directory not found: ${jsonDir.path}');
    exit(1);
  }

  final summary = generateSummary(jsonDir);
  mdFile.writeAsStringSync(summary);
  print('Summary written to ${mdFile.path}');
}
