// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
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

const _targets = <({String name, String serverPath, String? exceptionsPath})>[
  (name: 'shelf', serverPath: 'bin/shelf_echo.dart', exceptionsPath: null),
];

void main(List<String> args) async {
  print('Building Http11Probe...');
  await buildProbe();

  for (final target in _targets) {
    if (args.isNotEmpty && !args.contains(target.name)) continue;
    await _updateTarget(
      name: target.name,
      serverPath: target.serverPath,
      exceptionsPath: target.exceptionsPath,
    );
  }
}

Future<void> _updateTarget({
  required String name,
  required String serverPath,
  String? exceptionsPath,
}) async {
  final tempDir = Directory.systemTemp.createTempSync('compliance_${name}_');

  try {
    print('Temp directory for $name: ${tempDir.path}');

    Directory(
      p.join(tempDir.path, 'reports', name),
    ).createSync(recursive: true);

    for (final category in _categories) {
      print('Running compliance harness for $name / $category...');
      final reportFile = p.join(
        tempDir.path,
        'reports',
        name,
        '$category.json',
      );

      Directory(p.dirname(reportFile)).createSync(recursive: true);

      final filteredResults = await runComplianceHarness(
        serverPath: serverPath,
        category: category,
        reportFile: reportFile,
      );

      final encoder = const JsonEncoder.withIndent('  ');
      File(
        reportFile,
      ).writeAsStringSync('${encoder.convert(filteredResults)}\n');

      print('Updating golden report for $name / $category...');
      updateGoldenResults(
        category: category,
        name: name,
        results: filteredResults,
      );
    }

    print('Generating combined summary for $name...');
    final reportsDir = Directory(p.join(tempDir.path, 'reports', name));
    final summary = generateSummary(
      reportsDir,
      acceptedIds: loadAcceptedIds(exceptionsPath),
    );

    final goldenSummary = File('${name}_summary.md');
    final sanitizedSummary = canonicalize(summary, 0);

    print('Updating golden summary for $name...');
    goldenSummary.writeAsStringSync(sanitizedSummary);

    print('Goldens updated successfully for $name!');
  } finally {
    print('Cleaning up temp directory: ${tempDir.path}');
    tempDir.deleteSync(recursive: true);
  }
}
