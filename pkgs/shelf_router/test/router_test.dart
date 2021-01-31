// Copyright 2019 Google LLC
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

@TestOn('vm')
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

void main() {
  // Create a server that listens on localhost for testing
  late io.IOServer server;

  setUp(() async {
    try {
      server = await io.IOServer.bind(InternetAddress.loopbackIPv6, 0);
    } on SocketException catch (_) {
      server = await io.IOServer.bind(InternetAddress.loopbackIPv4, 0);
    }
  });

  tearDown(() => server.close());

  Future<String> get(String path) =>
      http.read(Uri.parse(server.url.toString() + path));
  Future<int> head(String path) async =>
      (await http.head(Uri.parse(server.url.toString() + path))).statusCode;

  test('get sync/async handler', () async {
    var app = Router();

    app.get('/sync-hello', (Request request) {
      return Response.ok('hello-world');
    });

    app.get('/async-hello', (Request request) async {
      return Future.microtask(() {
        return Response.ok('hello-world');
      });
    });

    // check that catch-alls work
    app.all('/<path|[^]*>', (Request request) {
      return Response.ok('not-found');
    });

    server.mount(app);

    expect(await get('/sync-hello'), 'hello-world');
    expect(await get('/async-hello'), 'hello-world');
    expect(await get('/wrong-path'), 'not-found');

    expect(await head('/sync-hello'), 200);
    expect(await head('/async-hello'), 200);
    expect(await head('/wrong-path'), 200);
  });

  test('params', () async {
    var app = Router();

    app.get(r'/user/<user>/groups/<group|\d+>', (Request request) {
      final user = params(request, 'user');
      final group = params(request, 'group');
      return Response.ok('$user / $group');
    });

    server.mount(app);

    expect(await get('/user/jonasfj/groups/42'), 'jonasfj / 42');
  });

  test('params by arguments', () async {
    var app = Router();

    app.get(r'/user/<user>/groups/<group|\d+>',
        (Request request, String user, String group) {
      return Response.ok('$user / $group');
    });

    server.mount(app);

    expect(await get('/user/jonasfj/groups/42'), 'jonasfj / 42');
  });

  test('mount(Router)', () async {
    var api = Router();
    api.get('/user/<user>/info', (Request request, String user) {
      return Response.ok('Hello $user');
    });

    var app = Router();
    app.get('/hello', (Request request) {
      return Response.ok('hello-world');
    });

    app.mount('/api/', api);

    app.all('/<_|[^]*>', (Request request) {
      return Response.notFound('catch-all-handler');
    });

    server.mount(app);

    expect(await get('/hello'), 'hello-world');
    expect(await get('/api/user/jonasfj/info'), 'Hello jonasfj');
    expect(get('/api/user/jonasfj/info-wrong'), throwsA(anything));
  });

  test('mount(Handler) with middleware', () async {
    var api = Router();
    api.get('/hello', (Request request) {
      return Response.ok('Hello');
    });

    final middleware = createMiddleware(
      requestHandler: (request) {
        if (request.url.queryParameters.containsKey('ok')) {
          return Response.ok('middleware');
        }
        return null;
      },
    );

    var app = Router();
    app.mount(
      '/api/',
      Pipeline().addMiddleware(middleware).addHandler(api),
    );

    server.mount(app);

    expect(await get('/api/hello'), 'Hello');
    expect(await get('/api/hello?ok'), 'middleware');
  });
}
