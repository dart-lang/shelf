// Copyright 2024 Google LLC
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
import 'package:test/test.dart';

void main() {
  test('logHops logs the number of hops', () async {
    final logs = <String>[];
    void logger(String message) => logs.add(message);

    final handler = const Pipeline()
        .addMiddleware(logHops(logger))
        .addHandler((Request request) {
      return Response.ok('ok', context: {'shelf_router.hops': 3});
    });

    final request = Request('GET', Uri.parse('http://localhost/test'));
    await handler(request);

    expect(logs, hasLength(1));
    expect(logs.first, contains('Request to test took 3 trie hops'));
  });

  test('logHops does nothing if hops are missing', () async {
    final logs = <String>[];
    void logger(String message) => logs.add(message);

    final handler = const Pipeline()
        .addMiddleware(logHops(logger))
        .addHandler((Request request) {
      return Response.ok('ok');
    });

    final request = Request('GET', Uri.parse('http://localhost/test'));
    await handler(request);

    expect(logs, isEmpty);
  });

  test('logHops integrates with Router', () async {
    final logs = <String>[];
    void logger(String message) => logs.add(message);

    final router = Router();
    router.get('/hello/:name', (Request request, String name) {
      return Response.ok('hi $name');
    });

    final handler =
        const Pipeline().addMiddleware(logHops(logger)).addHandler(router.call);

    final request = Request('GET', Uri.parse('http://localhost/hello/alice'));
    await handler(request);

    expect(logs, hasLength(1));
    // /hello/:name should be 2 hops
    expect(logs.first, contains('Request to hello/alice took 2 trie hops'));
  });
}
