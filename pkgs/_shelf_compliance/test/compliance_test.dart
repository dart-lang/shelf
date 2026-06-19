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

final _improvements = <Map<String, String>>[];
final _regressions = <Map<String, String>>[];
final _benignChanges = <Map<String, String>>[];
var _totalProbeTests = 0;
var _matchingBaseline = 0;

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

      // Write to GITHUB_STEP_SUMMARY if present
      final stepSummaryPath = Platform.environment['GITHUB_STEP_SUMMARY'];
      if (stepSummaryPath != null) {
        final file = File(stepSummaryPath);
        final buffer = StringBuffer();
        buffer.writeln('## 🛡️ HTTP/1.1 Compliance Test Summary');
        buffer.writeln();

        if (_regressions.isNotEmpty) {
          buffer.writeln('### ❌ Regressions Detected');
          buffer.writeln(
            'The following tests regressed compared to the baseline. '
            'The build has been marked as failed.',
          );
          buffer.writeln();
          buffer.writeln(
            '| Test ID | Category | Baseline Verdict | Actual Verdict |',
          );
          buffer.writeln('| --- | --- | --- | --- |');
          for (var r in _regressions) {
            buffer.writeln(
              '| `${r['id']}` | ${r['category']} | '
              '**${r['expected']}** | **${r['actual']}** |',
            );
          }
          buffer.writeln();
        }

        if (_improvements.isNotEmpty) {
          buffer.writeln('### 🚀 Improvements Detected');
          buffer.writeln(
            'The following tests improved compared to the baseline! '
            'Please run `dart run tool/update_goldens.dart` in '
            '`pkgs/_shelf_compliance` to update the goldens.',
          );
          buffer.writeln();
          buffer.writeln(
            '| Test ID | Category | Baseline Verdict | Actual Verdict |',
          );
          buffer.writeln('| --- | --- | --- | --- |');
          for (var imp in _improvements) {
            buffer.writeln(
              '| `${imp['id']}` | ${imp['category']} | '
              '**${imp['expected']}** | **${imp['actual']}** |',
            );
          }
          buffer.writeln();
        }

        if (_benignChanges.isNotEmpty) {
          buffer.writeln('### ⚠️ Benign Changes Detected');
          buffer.writeln(
            'The following tests had benign changes (verdicts remain '
            'unchanged). Please run `dart run tool/update_goldens.dart` '
            'to update.',
          );
          buffer.writeln();
          buffer.writeln('| Test ID | Category | Verdict |');
          buffer.writeln('| --- | --- | --- |');
          for (var bc in _benignChanges) {
            buffer.writeln(
              '| `${bc['id']}` | ${bc['category']} | **${bc['verdict']}** |',
            );
          }
          buffer.writeln();
        }

        if (_regressions.isEmpty &&
            _improvements.isEmpty &&
            _benignChanges.isEmpty) {
          buffer.writeln(
            '> 🎉 **All $_totalProbeTests compliance tests match the '
            'baseline perfectly!** No changes or regressions detected '
            'compared to the goldens.',
          );
          buffer.writeln();
        } else {
          buffer.writeln('### 📊 Stats Overview');
          buffer.writeln('*   **Total tests compared**: $_totalProbeTests');
          buffer.writeln('*   ✅ **Matches baseline**: $_matchingBaseline');
          if (_improvements.isNotEmpty) {
            buffer.writeln('*   🚀 **Improved**: ${_improvements.length}');
          }
          if (_benignChanges.isNotEmpty) {
            buffer.writeln(
              '*   ⚠️ **Benign changes**: ${_benignChanges.length}',
            );
          }
          if (_regressions.isNotEmpty) {
            buffer.writeln('*   ❌ **Regressions**: ${_regressions.length}');
          }
          buffer.writeln();
        }

        file.writeAsStringSync(buffer.toString(), mode: FileMode.append);
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
      result.remove('doubleFlush');
    }

    expect(
      filteredMaps.length,
      equals(expectedResults.length),
      reason: 'Length of results changed',
    );

    final failures = <String>[];
    for (var i = 0; i < filteredMaps.length; i++) {
      final actual = filteredMaps[i];
      final expected = expectedResults[i];
      _totalProbeTests++;

      expect(actual['id'], equals(expected['id']));

      final actualVerdictStr = actual['verdict'] as String;
      final expectedVerdictStr = expected['verdict'] as String;

      final actualRank = _verdictRank[actualVerdictStr] ?? 0;
      final expectedRank = _verdictRank[expectedVerdictStr] ?? 0;

      if (actualRank < expectedRank) {
        reportRegression();
        _regressions.add({
          'id': actual['id'] as String,
          'category': category,
          'expected': expectedVerdictStr,
          'actual': actualVerdictStr,
        });
        failures.add(
          'Test ${actual['id']} regressed from $expectedVerdictStr to '
          '$actualVerdictStr',
        );
      } else if (actualRank > expectedRank) {
        _improvements.add({
          'id': actual['id'] as String,
          'category': category,
          'expected': expectedVerdictStr,
          'actual': actualVerdictStr,
        });
        _printGithubWarning(
          'pkgs/_shelf_compliance/reports/$name/$category.json',
          'Compliance Test Improved!',
          'Test ${actual['id']} improved from $expectedVerdictStr to '
              '$actualVerdictStr. Run tool/update_goldens.dart to tighten.',
        );
      } else {
        if (!const DeepCollectionEquality().equals(actual, expected)) {
          _benignChanges.add({
            'id': actual['id'] as String,
            'category': category,
            'verdict': actualVerdictStr,
          });
          _printGithubWarning(
            'pkgs/_shelf_compliance/reports/$name/$category.json',
            'Compliance Test Changed!',
            'Test ${actual['id']} changed benignly (verdict remains '
                '$actualVerdictStr). Run tool/update_goldens.dart to tighten.',
          );
        } else {
          _matchingBaseline++;
        }
      }
    }

    if (failures.isNotEmpty) {
      fail(failures.join('\n'));
    }
  });
}
