// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'compliance_result.dart';

/// Generates a combined Markdown summary from all JSON reports in [jsonDir].
String generateSummary(Directory jsonDir) {
  final files = jsonDir.listSync().whereType<File>().where(
    (file) => p.extension(file.path) == '.json',
  );

  final allResults = <ComplianceResult>[];

  for (var file in files) {
    final content = file.readAsStringSync();
    final decoded = (json.decode(content) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    allResults.addAll(decoded.map(ComplianceResult.fromJson));
  }

  // Sort results by ID for stable output
  allResults.sort((a, b) => a.id.compareTo(b.id));

  final total = allResults.length;
  var passed = 0;
  var failed = 0;
  var warnings = 0;
  var errors = 0;

  for (var res in allResults) {
    final verdict = res.verdict;
    switch (verdict) {
      case ResultVerdict.Pass:
        passed++;
        break;
      case ResultVerdict.Fail:
        failed++;
        break;
      case ResultVerdict.Warn:
        warnings++;
        break;
      case ResultVerdict.Error:
        errors++;
        break;
      case ResultVerdict.Skip:
        throw UnsupportedError('should not have skips here!');
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
| Errors | $errors |

## Failed or Warning Results

| ID | Category | Verdict | Description |
| --- | --- | --- | --- |
''');

  for (var res in allResults) {
    if (res.verdict != ResultVerdict.Pass &&
        res.verdict != ResultVerdict.Skip) {
      buffer.writeln(
        '| ${res.id} | ${res.category} | ${res.verdict.name} | '
        '${res.description} |',
      );
    }
  }

  return buffer.toString();
}
