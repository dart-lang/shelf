// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

void main() async {
  const numRoutes = 10000;
  const iterations = 100000;

  print('Generating $numRoutes routes...');
  final router = Router();

  for (var i = 1; i <= 10; i++) {
    for (var j = 1; j <= 1000; j++) {
      router.get('/tree$i/test$j', (Request request) => Response.ok('ok'));
    }
  }

  // Worst-case match: Last route added
  const worstCasePath = '/tree10/test1000';
  print('Benchmarking worst-case match for: $worstCasePath');

  final request = Request('GET', Uri.parse('http://localhost$worstCasePath'));

  // Warm up
  for (var i = 0; i < 1000; i++) {
    router.call(request);
  }

  final stopwatch = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    router.call(request);
  }
  stopwatch.stop();

  final totalMs = stopwatch.elapsedMilliseconds;
  final avgUs = (stopwatch.elapsedMicroseconds / iterations).toStringAsFixed(3);

  print('-----------------------------------------');
  print('Total Time for $iterations matches: ${totalMs}ms');
  print('Average Time per Match: $avgUsμs');
  print('-----------------------------------------');

  // Benchmark 404
  const path404 = '/non-existent/route/path';
  print('\nBenchmarking 404 (Not Found) for: $path404');
  final request404 = Request('GET', Uri.parse('http://localhost$path404'));

  stopwatch.reset();
  stopwatch.start();
  for (var i = 0; i < iterations; i++) {
    router.call(request404);
  }
  stopwatch.stop();

  final totalMs404 = stopwatch.elapsedMilliseconds;
  final avgUs404 =
      (stopwatch.elapsedMicroseconds / iterations).toStringAsFixed(3);

  print('-----------------------------------------');
  print('Total Time for $iterations 404s: ${totalMs404}ms');
  print('Average Time per 404: $avgUs404μs');
  print('-----------------------------------------');
}
