// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:_shelf_compliance/src/compliance_harness.dart';
import 'package:_shelf_compliance/src/generate_summary.dart';
import 'package:path/path.dart' as p;

const _categories = [
  'Capabilities',
  'Compliance',
  'Cookies',
  'Injection',
  'MalformedInput',
  'Normalization',
  'ResourceLimits',
  'Smuggling',
  'WebSockets',
];

void main() async {
  const name = 'shelf';
  const serverPath = 'bin/shelf_echo.dart';

  final tempDir = Directory.systemTemp.createTempSync('compliance_${name}_');

  try {
    print('Temp directory for $name: ${tempDir.path}');
    print('Building Http11Probe...');
    await buildProbe();

    // Create reports directory
    Directory(
      p.join(tempDir.path, 'reports', name),
    ).createSync(recursive: true);

    for (var category in _categories) {
      print('Running compliance harness for $category...');
      final reportFile = p.join(
        tempDir.path,
        'reports',
        name,
        '$category.json',
      );

      // Create directory for report file if it doesn't exist
      Directory(p.dirname(reportFile)).createSync(recursive: true);

      final filteredResults = await runComplianceHarness(
        serverPath: serverPath,
        category: category,
        reportFile: reportFile,
      );

      // Overwrite the report file in temp dir with pruned results
      final encoder = const JsonEncoder.withIndent('  ');
      File(
        reportFile,
      ).writeAsStringSync('${encoder.convert(filteredResults)}\n');

      print('Updating golden report for $category...');
      updateGoldenResults(
        category: category,
        name: name,
        results: filteredResults,
      );
    }

    print('Generating combined summary for $name...');
    final reportsDir = Directory(p.join(tempDir.path, 'reports', name));
    final summary = generateSummary(reportsDir);

    final goldenSummary = File('${name}_summary.md');

    final sanitizedSummary = canonicalize(summary, 0);

    print('Updating golden summary for $name...');
    goldenSummary.writeAsStringSync(sanitizedSummary);

    print('Goldens updated successfully!');
  } finally {
    print('Cleaning up temp directory: ${tempDir.path}');
    tempDir.deleteSync(recursive: true);
  }
}
