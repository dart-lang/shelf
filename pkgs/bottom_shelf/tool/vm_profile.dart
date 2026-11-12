// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Minimal vm_service JSON-RPC client: CPU samples + allocation profile.
// Usage:
//   dart vm_profile.dart <ws-uri> <cpu|cpu-clear|alloc-reset|alloc-read>
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final wsUri = args[0];
  final mode = args[1];
  final ws = await WebSocket.connect(wsUri);
  var nextId = 1;
  final pending = <int, Completer<Map<String, dynamic>>>{};

  ws.listen((data) {
    final msg = jsonDecode(data as String) as Map<String, dynamic>;
    final id = msg['id'];
    if (id != null) {
      final c = pending.remove(int.parse(id as String));
      if (msg.containsKey('error')) {
        c?.completeError(msg['error'].toString());
      } else {
        c?.complete(msg['result'] as Map<String, dynamic>);
      }
    }
  });

  Future<Map<String, dynamic>> rpc(
    String method, [
    Map<String, dynamic>? params,
  ]) {
    final id = nextId++;
    final c = Completer<Map<String, dynamic>>();
    pending[id] = c;
    ws.add(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': '$id',
        'method': method,
        'params': params ?? {},
      }),
    );
    return c.future.timeout(const Duration(seconds: 120));
  }

  final vm = await rpc('getVM');
  final isolateId =
      ((vm['isolates'] as List).first as Map<String, dynamic>)['id'] as String;

  switch (mode) {
    case 'cpu-clear':
      await rpc('clearCpuSamples', {'isolateId': isolateId});
      print('cleared');
    case 'cpu':
      final r = await rpc('getCpuSamples', {
        'isolateId': isolateId,
        'timeOriginMicros': 0,
        'timeExtentMicros': 0x7fffffffffffff,
      });
      final functions = r['functions'] as List;
      final samples = r['samples'] as List;
      final selfCounts = <int, int>{};
      final inclusiveCounts = <int, int>{};
      for (final s in samples) {
        final stack = (s as Map<String, dynamic>)['stack'] as List;
        if (stack.isEmpty) continue;
        selfCounts.update(stack.first as int, (v) => v + 1, ifAbsent: () => 1);
        for (final f in stack.toSet()) {
          inclusiveCounts.update(f as int, (v) => v + 1, ifAbsent: () => 1);
        }
      }
      String nameOf(int idx) {
        final f = functions[idx] as Map<String, dynamic>;
        final fn = f['function'] as Map<String, dynamic>;
        var name = fn['name'] as String? ?? '?';
        final owner = fn['owner'];
        if (owner is Map<String, dynamic> && owner['name'] != null) {
          name = '${owner['name']}.$name';
        }
        return name;
      }

      final total = samples.length;
      print('TOTAL_SAMPLES $total');
      print('--- SELF (top 40) ---');
      final selfSorted = selfCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in selfSorted.take(40)) {
        final pct = (e.value * 100 / total).toStringAsFixed(1);
        print('$pct% ${e.value} ${nameOf(e.key)}');
      }
      print('--- INCLUSIVE (top 40) ---');
      final incSorted = inclusiveCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in incSorted.take(40)) {
        final pct = (e.value * 100 / total).toStringAsFixed(1);
        print('$pct% ${e.value} ${nameOf(e.key)}');
      }
    case 'alloc-reset':
      await rpc('getAllocationProfile', {
        'isolateId': isolateId,
        'reset': true,
      });
      print('reset');
    case 'alloc-read':
      final r = await rpc('getAllocationProfile', {'isolateId': isolateId});
      final members = r['members'] as List;
      final rows = <(String, int, int)>[];
      for (final m in members) {
        final mm = m as Map<String, dynamic>;
        final cls = mm['class'] as Map<String, dynamic>?;
        final count = mm['instancesAccumulated'] as int? ?? 0;
        final bytes = mm['bytesCurrent'] as int? ?? 0;
        if (count > 0) {
          rows.add((cls?['name'] as String? ?? '?', count, bytes));
        }
      }
      rows.sort((a, b) => b.$2.compareTo(a.$2));
      print('--- ALLOCATIONS since reset (top 45 by instance count) ---');
      for (final r2 in rows.take(45)) {
        print('${r2.$2}\t${r2.$1}');
      }
  }
  await ws.close();
  exit(0);
}
