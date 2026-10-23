// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'compliance_result.dart';

/// Loads accepted probe IDs from a YAML exceptions file, or returns an empty
/// set when [exceptionsPath] is `null`.
Set<String> loadAcceptedIds(String? exceptionsPath) {
  if (exceptionsPath == null) return const {};
  final content = File(exceptionsPath).readAsStringSync();
  final entries = loadYaml(content) as YamlList;
  return {
    for (final entry in entries.cast<YamlMap>())
      for (final testId in (entry['tests'] as YamlList).cast<String>()) testId,
  };
}

/// Generates a combined Markdown summary from all JSON reports in [jsonDir].
///
/// Failures and warnings whose IDs appear in [acceptedIds] are counted under
/// `Accepted` and omitted from the `Failed or Warning Results` table.
String generateSummary(
  Directory jsonDir, {
  Set<String> acceptedIds = const <String>{},
}) {
  final files = jsonDir.listSync().whereType<File>().where(
    (file) => p.extension(file.path) == '.json',
  );

  final allResults = <ComplianceResult>[];

  for (final file in files) {
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
  var accepted = 0;
  var errors = 0;

  for (final res in allResults) {
    switch ((res.verdict, acceptedIds.contains(res.id))) {
      case (ResultVerdict.Pass, _):
        passed++;
      case (ResultVerdict.Fail || ResultVerdict.Warn, true):
        accepted++;
      case (ResultVerdict.Fail, false):
        failed++;
      case (ResultVerdict.Warn, false):
        warnings++;
      case (ResultVerdict.Error, _):
        errors++;
      case (ResultVerdict.Skip, _):
        throw UnsupportedError('should not have skips here!');
    }
  }

  final buffer = StringBuffer()
    ..write('''
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

  for (final res in allResults) {
    if (res.verdict != ResultVerdict.Pass &&
        res.verdict != ResultVerdict.Skip &&
        !acceptedIds.contains(res.id)) {
      buffer.writeln(
        '| ${res.id} | ${res.category} | ${res.verdict.name} | '
        '${res.description} |',
      );
    }
  }

  return buffer.toString();
}
