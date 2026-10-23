// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:_shelf_compliance/src/generate_summary.dart';

void main(List<String> args) {
  if (args.length < 2) {
    print(
      'Usage: dart generate_summary.dart <json_directory> <markdown_file> '
      '[exceptions_yaml]',
    );
    exit(1);
  }

  final jsonDir = Directory(args[0]);
  final mdFile = File(args[1]);
  final exceptionsPath = args.length >= 3 ? args[2] : null;

  if (!jsonDir.existsSync()) {
    print('Error: Directory not found: ${jsonDir.path}');
    exit(1);
  }

  final summary = generateSummary(
    jsonDir,
    acceptedIds: loadAcceptedIds(exceptionsPath),
  );
  mdFile.writeAsStringSync(summary);
  print('Summary written to ${mdFile.path}');
}
