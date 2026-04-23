// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'compliance_result.dart';

/// Remove report information that changes with every run for ease of
/// comparison.
String canonicalize(String content, int port) {
  var result = content.replaceAll(':$port', ':<PORT>');
  // Replace durations
  result = result.replaceAll(
    RegExp(r'"durationMs": \d+\.\d+'),
    '"durationMs": 0.0',
  );
  // Replace dates in raw headers (e.g., date: Tue, 21 Apr 2026 19:01:21 GMT)
  result = result.replaceAll(RegExp(r'date: [^\r\n\\"]+'), 'date: <DATE>');
  return result;
}

/// Build the probe tool once.
Future<void> buildProbe() async {
  final buildResult = await Process.run('dotnet', [
    'build',
    '../../vendor/Http11Probe/src/Http11Probe.Cli',
    '--output',
    'tool/probe_bin',
  ]);

  if (buildResult.exitCode != 0) {
    print(buildResult.stdout);
    print(buildResult.stderr);
    throw Exception(
      'Failed to build Http11Probe (exit code ${buildResult.exitCode})',
    );
  }
}

/// Start the echo server and extract the dynamic port.
Future<(Process, int)> _startServer(String serverPath) async {
  final process = await Process.start(Platform.resolvedExecutable, [
    serverPath,
  ]);

  final lines = process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter());
  final portLine = await lines.first;
  final port = int.parse(portLine.split(': ').last);

  return (process, port);
}

/// Runs the HTTP/1.1 compliance probe for a specific category.
/// Returns the filtered and sorted results.
Future<List<ComplianceResult>> runComplianceHarness({
  required String serverPath,
  required String category,
  required String reportFile,
}) async {
  final (serverProcess, port) = await _startServer(serverPath);

  final probeResult = await Process.run('dotnet', [
    'tool/probe_bin/Http11Probe.Cli.dll',
    '--host',
    '127.0.0.1',
    '--port',
    '$port',
    '--category',
    category,
    '--output',
    reportFile,
  ]);

  if (probeResult.stdout != null) {
    print(probeResult.stdout);
  }

  // Read and sanitize file
  final currentReportStr = canonicalize(
    File(reportFile).readAsStringSync(),
    port,
  );
  final currentData = json.decode(currentReportStr) as Map<String, dynamic>;

  final rawResults = (currentData['results'] as List<dynamic>)
      .cast<Map<String, dynamic>>();

  for (var result in rawResults) {
    result.remove('durationMs');
    result.remove('connectionState');
    result.remove('scored');
    result.remove('doubleFlush');
  }

  final currentResults = rawResults
      .map(ComplianceResult.fromJson)
      .where((result) => result.verdict != ResultVerdict.Skip)
      .toList();

  currentResults.sort((a, b) => a.id.compareTo(b.id));

  // Clean up server
  serverProcess.kill();
  await serverProcess.exitCode;

  return currentResults;
}

/// Updates the golden baseline results for a test category.
void updateGoldenResults({
  required String category,
  required String name,
  required List<ComplianceResult> results,
}) {
  final reportsDir = Directory('reports/$name');
  if (!reportsDir.existsSync()) {
    reportsDir.createSync(recursive: true);
  }
  final goldenReport = File('reports/$name/$category.json');

  // Save sorted and pretty JSON array
  final encoder = const JsonEncoder.withIndent('  ');
  goldenReport.writeAsStringSync('${encoder.convert(results)}\n');
}
