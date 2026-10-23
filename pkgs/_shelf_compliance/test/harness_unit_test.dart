// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:_shelf_compliance/echo_handler.dart';
import 'package:_shelf_compliance/src/compliance_harness.dart';
import 'package:_shelf_compliance/src/generate_summary.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('canonicalize', () {
    test('normalizes port, durationMs, and Date headers preserving case', () {
      const raw = [
        '{"url":"http://127.0.0.1:54321/echo","durationMs": 12.34,',
        r'"headers":"date: Tue, 21 Apr 2026 19:01:21 GMT\r\n',
        r'Date: Tue, 21 Apr 2026 19:01:22 GMT\r\n"}',
      ];

      expect(
        canonicalize(raw.join(), 54321),
        [
          '{"url":"http://127.0.0.1:<PORT>/echo","durationMs": 0.0,',
          r'"headers":"date: <DATE>\r\nDate: <DATE>\r\n"}',
        ].join(),
      );
    });
  });

  group('loadAcceptedIds and generateSummary', () {
    test('buckets accepted Fail and Warn IDs and omits them from table', () {
      final tempDir = Directory.systemTemp.createTempSync('summary_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final reportsDir = Directory(p.join(tempDir.path, 'reports'))
        ..createSync();
      File(p.join(reportsDir.path, 'Compliance.json')).writeAsStringSync(
        json.encode([
          {
            'id': 'COMP-PASS',
            'category': 'Compliance',
            'description': 'Passes cleanly',
            'verdict': 'Pass',
          },
          {
            'id': 'COMP-ACCEPTED-FAIL',
            'category': 'Compliance',
            'description': 'Accepted trade-off',
            'verdict': 'Fail',
          },
          {
            'id': 'COMP-ACCEPTED-WARN',
            'category': 'Compliance',
            'description': 'Accepted warning',
            'verdict': 'Warn',
          },
          {
            'id': 'COMP-REAL-FAIL',
            'category': 'Compliance',
            'description': 'Unaccepted failure',
            'verdict': 'Fail',
          },
        ]),
      );

      final exceptionsFile = File(p.join(tempDir.path, 'exceptions.yaml'))
        ..writeAsStringSync('''
- description: Known trade-offs
  tests:
    - COMP-ACCEPTED-FAIL
    - COMP-ACCEPTED-WARN
''');

      expect(loadAcceptedIds(null), isEmpty);
      final acceptedIds = loadAcceptedIds(exceptionsFile.path);
      expect(acceptedIds, {'COMP-ACCEPTED-FAIL', 'COMP-ACCEPTED-WARN'});

      final summary = generateSummary(reportsDir, acceptedIds: acceptedIds);
      expect(summary, contains('| Total | 4 |'));
      expect(summary, contains('| Passed | 1 |'));
      expect(summary, contains('| Failed | 1 |'));
      expect(summary, contains('| Warnings | 0 |'));
      expect(summary, contains('| Accepted | 2 |'));
      expect(summary, contains('| COMP-REAL-FAIL |'));
      expect(summary, isNot(contains('COMP-ACCEPTED-FAIL')));
      expect(summary, isNot(contains('COMP-ACCEPTED-WARN')));
    });
  });

  group('echo handler', () {
    test('serves GET /, POST /, /echo, /cookie, and 404', () async {
      final getRoot = await handler(Request('GET', Uri.http('localhost', '/')));
      expect(getRoot.statusCode, 200);
      expect(await getRoot.readAsString(), 'OK');

      final postRoot = await handler(
        Request('POST', Uri.http('localhost', '/'), body: 'payload'),
      );
      expect(await postRoot.readAsString(), 'payload');

      final echoRes = await handler(
        Request(
          'GET',
          Uri.http('localhost', '/echo'),
          headers: {'x-test': '42'},
        ),
      );
      expect(await echoRes.readAsString(), contains('x-test: 42\r\n'));

      final cookieRes = await handler(
        Request(
          'GET',
          Uri.http('localhost', '/cookie'),
          headers: {'cookie': 'a=1; b=two=2; bare'},
        ),
      );
      expect(await cookieRes.readAsString(), 'a=1\r\nb=two=2\r\nbare=\r\n');

      final missing = await handler(
        Request('GET', Uri.http('localhost', '/other')),
      );
      expect(missing.statusCode, 404);
    });
  });
}
