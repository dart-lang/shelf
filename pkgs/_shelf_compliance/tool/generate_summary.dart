import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// Generates a combined Markdown summary from all JSON reports in [jsonDir].
String generateSummary(Directory jsonDir) {
  final files = jsonDir.listSync().whereType<File>().where(
    (file) => p.extension(file.path) == '.json',
  );

  final allResults = <Map<String, dynamic>>[];

  for (var file in files) {
    final content = file.readAsStringSync();
    final decoded = json.decode(content);
    final results = decoded is List
        ? decoded
        : (decoded as Map<String, dynamic>)['results'] as List;

    for (var result in results) {
      final res = result as Map<String, dynamic>;
      if (res['verdict'] != 'Skip') {
        allResults.add(res);
      }
    }
  }

  // Sort results by ID for stable output
  allResults.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));

  final total = allResults.length;
  var passed = 0;
  var failed = 0;
  var warnings = 0;
  var errors = 0;
  var skipped = 0;

  for (var res in allResults) {
    final verdict = res['verdict'] as String;
    switch (verdict) {
      case 'Pass':
        passed++;
        break;
      case 'Fail':
        failed++;
        break;
      case 'Warn':
        warnings++;
        break;
      case 'Error':
        errors++;
        break;
      case 'Skip':
        skipped++;
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
| Errors | $errors |
| Skipped | $skipped |

## Failed or Warning Results

| ID | Category | Verdict | Description |
| --- | --- | --- | --- |
''');

  for (var res in allResults) {
    final verdict = res['verdict'] as String;
    if (verdict != 'Pass' && verdict != 'Skip') {
      buffer.writeln(
        '| ${res['id']} | ${res['category']} | $verdict | '
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
