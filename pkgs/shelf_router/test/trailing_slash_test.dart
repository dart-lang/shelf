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
import 'package:test/test.dart';

void main() {
  test('removeTrailingSlash strips trailing slash', () async {
    final router = Router();
    router.get('/hello', (Request request) => Response.ok('ok'));

    final handler = const Pipeline()
        .addMiddleware(removeTrailingSlash())
        .addHandler(router.call);

    // Request without trailing slash should work
    var request = Request('GET', Uri.parse('http://localhost/hello'));
    var response = await handler(request);
    expect(response.statusCode, 200);

    // Request with trailing slash should be normalized and work
    request = Request('GET', Uri.parse('http://localhost/hello/'));
    response = await handler(request);
    expect(response.statusCode, 200);
  });

  test('removeTrailingSlash does not strip root slash', () async {
    final router = Router();
    router.get('/', (Request request) => Response.ok('root'));

    final handler = const Pipeline()
        .addMiddleware(removeTrailingSlash())
        .addHandler(router.call);

    final request = Request('GET', Uri.parse('http://localhost/'));
    final response = await handler(request);
    expect(response.statusCode, 200);
    expect(await response.readAsString(), 'root');
  });

  test('combining removeTrailingSlash, logHops, and logRequests', () async {
    final hopLogs = <String>[];
    final requestLogs = <String>[];

    final router = Router();
    router.get('/user/:id', (Request request, String id) {
      return Response.ok('user $id');
    });

    final handler = const Pipeline()
        .addMiddleware(removeTrailingSlash())
        // logRequests typically prints to stdout, we'll simulate its behavior
        // or just ensure it doesn't crash the pipeline.
        .addMiddleware(
            logRequests(logger: (msg, isError) => requestLogs.add(msg)))
        .addMiddleware(logHops((msg) => hopLogs.add(msg)))
        .addHandler(router.call);

    // Request with trailing slash
    final request = Request('GET', Uri.parse('http://localhost/user/123/'));
    final response = await handler(request);

    expect(response.statusCode, 200);
    expect(await response.readAsString(), 'user 123');

    // Verify logHops worked (should be 2 hops: /user and :id)
    expect(hopLogs, hasLength(1));
    expect(hopLogs.first, contains('Request to user/123 took 2 trie hops'));

    // Verify logRequests worked
    expect(requestLogs, hasLength(1));
    expect(requestLogs.first, contains('GET'));
    expect(requestLogs.first, contains('200'));
  });
}
