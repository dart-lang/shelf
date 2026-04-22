// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// Generates a combined Markdown summary from all JSON reports in [jsonDir].
String generateSummary(
  Directory jsonDir, {
  Set<String> acceptedIds = const <String>{},
}) {
  final files = jsonDir.listSync().whereType<File>().where(
    (file) => p.extension(file.path) == '.json',
  );

  final allResults = <Map<String, dynamic>>[];

  for (var file in files) {
    final content = file.readAsStringSync();
    final decoded = (json.decode(content) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    allResults.addAll(decoded);
  }

  // Sort results by ID for stable output
  allResults.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));

  final total = allResults.length;
  var passed = 0;
  var failed = 0;
  var warnings = 0;
  var errors = 0;
  var accepted = 0;

  for (var res in allResults) {
    final id = res['id'] as String;
    final verdict = res['verdict'] as String;
    final isAccepted = acceptedIds.contains(id);

    switch (verdict) {
      case 'Pass':
        passed++;
        break;
      case 'Fail':
        if (isAccepted) {
          accepted++;
        } else {
          failed++;
        }
        break;
      case 'Warn':
        if (isAccepted) {
          accepted++;
        } else {
          warnings++;
        }
        break;
      case 'Error':
        errors++;
        break;
    }
  }

  final buffer = StringBuffer();

  buffer.write('''
# Compliance Test Summary

| Category | Count |
| --- | --- |
| Total | $total |
| Passed | $passed |
| Failed | $failed |
| Warnings | $warnings |
| Accepted | $accepted |
| Errors | $errors |

## Failed or Warning Results

| ID | Category | Verdict | Description |
| --- | --- | --- | --- |
''');

  for (var res in allResults) {
    final id = res['id'] as String;
    final verdict = res['verdict'] as String;
    final isAccepted = acceptedIds.contains(id);

    if (verdict != 'Pass' && verdict != 'Skip' && !isAccepted) {
      buffer.writeln(
        '| $id | ${res['category']} | $verdict | '
        '${res['description']} |',
      );
    }
  }

  return buffer.toString();
}

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
