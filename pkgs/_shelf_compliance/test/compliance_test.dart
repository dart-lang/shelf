// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:_shelf_compliance/src/compliance_harness.dart';
import 'package:_shelf_compliance/src/generate_summary.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_process/test_process.dart';

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

/// Maps verdicts to a numeric rank for comparison.
///
/// We allow test results to move up the ranks (or stay same),
/// but not down.
const _verdictRank = {'Pass': 4, 'Warn': 3, 'Fail': 2, 'Error': 1, 'Skip': 0};

void _printGithubWarning(String filePath, String title, String message) {
  print('::warning file=$filePath,title=$title::$message');
}

void main() {
  test('Verify categories list is complete', () async {
    final helpProcess = await TestProcess.start('dotnet', [
      'run',
      '--project',
      '../../vendor/Http11Probe/src/Http11Probe.Cli',
      '--',
      '--help',
    ], forwardStdio: true);

    final buffer = StringBuffer();
    while (await helpProcess.stdout.hasNext) {
      buffer.writeln(await helpProcess.stdout.next);
    }
    final output = buffer.toString();

    await helpProcess.shouldExit(0);
    final categoryLine = output
        .split('\n')
        .firstWhere((line) => line.contains('--category'));

    final match = RegExp(r'<(.*)>').firstMatch(categoryLine);
    if (match != null) {
      final categoriesStr = match.group(1)!;
      final categories = categoriesStr.split('|');

      // Verify that our hardcoded list matches the tool's supported categories
      expect(categories, containsAll(_categories));
      expect(_categories, containsAll(categories));
    } else {
      fail('Could not find categories list in help output');
    }
  });

  _defineComplianceTests('shelf', 'bin/shelf_echo.dart');
}

void _defineComplianceTests(String name, String serverPath) {
  group(name, () {
    final tempDir = Directory.systemTemp.createTempSync('compliance_${name}_');
    var hasRegressions = false;

    void reportRegression() {
      hasRegressions = true;
    }

    setUpAll(() async {
      print('Temp directory for $name: ${tempDir.path}');

      print('Building Http11Probe...');
      await buildProbe();

      // Create reports directory
      Directory(
        p.join(tempDir.path, 'reports', name),
      ).createSync(recursive: true);
    });

    for (var category in _categories) {
      _testCompliance(
        name: name,
        serverPath: serverPath,
        category: category,
        tempDir: tempDir,
        reportRegression: reportRegression,
      );
    }

    tearDownAll(() async {
      print('Generating combined summary for $name...');
      final reportsDir = Directory(p.join(tempDir.path, 'reports', name));
      final summary = generateSummary(reportsDir);

      final goldenSummary = File('${name}_summary.md');

      final sanitizedSummary = canonicalize(
        summary,
        0,
      ); // No port to sanitize in summary usually

      if (!goldenSummary.existsSync()) {
        fail(
          'Golden summary missing! Please run tool/update_goldens.dart to '
          'create it.',
        );
      }
      final expectedSummary = goldenSummary.readAsStringSync();
      if (sanitizedSummary != expectedSummary) {
        if (hasRegressions) {
          print('MISMATCH in summary!');
          print('Generated summary in temp dir.');
          print('Golden summary: ${goldenSummary.path}');
          fail(
            'Generated summary does not match golden and there were '
            'regressions.',
          );
        } else {
          _printGithubWarning(
            'pkgs/_shelf_compliance/${name}_summary.md',
            'Compliance Summary Improved!',
            'The summary improved or changed benignly but does not match the '
                'golden. Run tool/update_goldens.dart to tighten.',
          );
        }
      }

      // Clean up temp directory
      print('Cleaning up temp directory: ${tempDir.path}');
      tempDir.deleteSync(recursive: true);
    });
  });
}

void _testCompliance({
  required String name,
  required String serverPath,
  required String category,
  required Directory tempDir,
  required void Function() reportRegression,
}) {
  test('Category: $category', () async {
    final reportFile = p.join(tempDir.path, 'reports', name, '$category.json');

    // Create directory for report file if it doesn't exist
    Directory(p.dirname(reportFile)).createSync(recursive: true);

    final filteredResults = await runComplianceHarness(
      serverPath: serverPath,
      category: category,
      reportFile: reportFile,
    );

    final filteredMaps = filteredResults.map((r) => r.toJson()).toList();

    // Overwrite the report file in temp dir with pruned results so summary tool
    // reads clean data
    final encoder = const JsonEncoder.withIndent('  ');
    File(reportFile).writeAsStringSync('${encoder.convert(filteredResults)}\n');

    // Compare with Goldens
    final goldenReport = File('reports/$name/$category.json');

    if (!goldenReport.existsSync()) {
      fail(
        'Golden report missing for $category! Please run tool/update_goldens.dart '
        'to create it.',
      );
    }

    final expectedResults =
        (json.decode(goldenReport.readAsStringSync()) as List<dynamic>)
            .cast<Map<String, dynamic>>();
    expectedResults.sort(
      (a, b) => (a['id'] as String).compareTo(b['id'] as String),
    );

    for (var result in expectedResults) {
      final res = result;
      res.remove('doubleFlush');
    }

    expect(
      filteredMaps.length,
      equals(expectedResults.length),
      reason: 'Length of results changed',
    );

    for (var i = 0; i < filteredMaps.length; i++) {
      final actual = filteredMaps[i];
      final expected = expectedResults[i];

      expect(actual['id'], equals(expected['id']));

      final actualVerdictStr = actual['verdict'] as String;
      final expectedVerdictStr = expected['verdict'] as String;

      final actualRank = _verdictRank[actualVerdictStr] ?? 0;
      final expectedRank = _verdictRank[expectedVerdictStr] ?? 0;

      if (actualRank < expectedRank) {
        reportRegression();

        expect(
          actual,
          equals(expected),
          reason:
              'Test ${actual['id']} regressed from $expectedVerdictStr to '
              '$actualVerdictStr',
        );
      } else if (actualRank > expectedRank) {
        _printGithubWarning(
          'pkgs/_shelf_compliance/reports/$name/$category.json',
          'Compliance Test Improved!',
          'Test ${actual['id']} improved from $expectedVerdictStr to '
              '$actualVerdictStr. Run tool/update_goldens.dart to tighten.',
        );
      } else {
        if (!const DeepCollectionEquality().equals(actual, expected)) {
          _printGithubWarning(
            'pkgs/_shelf_compliance/reports/$name/$category.json',
            'Compliance Test Changed!',
            'Test ${actual['id']} changed benignly (verdict remains '
                '$actualVerdictStr). Run tool/update_goldens.dart to tighten.',
          );
        }
      }
    }
  });
}
