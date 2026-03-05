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
library;

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

  Future<String> get(String path) => http.read(server.url.resolve(path));

  test('get sync/async handler', () async {
    var app = Router();

    app.get('/sync-hello', (Request request) {
      return Response.ok('hello-world', headers: {'X-Handler': 'sync'});
    });

    app.get('/async-hello', (Request request) async {
      return Future.microtask(() {
        return Response.ok('hello-world', headers: {'X-Handler': 'async'});
      });
    });

    // check that catch-alls work
    app.all('/<path|[^]*>', (Request request) {
      return Response.ok('not-found', headers: {'X-Handler': 'catch-all'});
    });

    server.mount(app.call);

    expect(await get('/sync-hello'), 'hello-world');
    expect(await get('/async-hello'), 'hello-world');
    expect(await get('/wrong-path'), 'not-found');

    Future<http.Response> headResponse(String path) =>
        http.head(server.url.resolve(path));

    expect((await headResponse('/sync-hello')).headers['x-handler'], 'sync');
    expect((await headResponse('/async-hello')).headers['x-handler'], 'async');
    expect(
        (await headResponse('/wrong-path')).headers['x-handler'], 'catch-all');
  });

  test('params', () async {
    var app = Router();

    app.get(r'/user/:user/groups/:group', (Request request) {
      final user = request.params['user'];
      final group = request.params['group'];
      return Response.ok('$user / $group');
    });

    server.mount(app.call);

    expect(await get('/user/jonasfj/groups/42'), 'jonasfj / 42');
  });

  test('mount(Router)', () async {
    var api = Router();
    api.get('/user/:user/info', (Request request) {
      final user = request.params['user'];
      return Response.ok('Hello $user');
    });

    var app = Router();
    app.get('/hello', (Request request) {
      return Response.ok('hello-world');
    });

    app.mount('/api/', api.call);

    app.all('/<*>', (Request request) {
      return Response.ok('catch-all-handler');
    });

    server.mount(app.call);

    expect(await get('/hello'), 'hello-world');
    expect(await get('/api/user/jonasfj/info'), 'Hello jonasfj');
    expect(await get('/api/user/jonasfj/info-wrong'), 'catch-all-handler');
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
      middleware.addHandler(api.call),
    );

    server.mount(app.call);

    expect(await get('/api/hello'), 'Hello');
    expect(await get('/api/hello?ok'), 'middleware');
  });

  test('mount(Router) without leading slash', () async {
    var api = Router();
    api.get('/hello', (Request request) {
      return Response.ok('Hello');
    });

    var app = Router();
    // Normalization test: 'api' instead of '/api'
    app.mount('api', api.call);

    server.mount(app.call);

    expect(await get('/api/hello'), 'Hello');
  });

  test('mount(Router) does not require a trailing slash', () async {
    var api = Router();
    api.get('/', (Request request) {
      return Response.ok('Hello World!');
    });

    api.get('/user/:user/info', (Request request) {
      final user = request.params['user'];
      return Response.ok('Hello $user');
    });

    var app = Router();
    app.get('/hello', (Request request) {
      return Response.ok('hello-world');
    });

    app.mount('/api', api.call);

    app.all('/<*>', (Request request) {
      return Response.ok('catch-all-handler');
    });

    server.mount(app.call);

    expect(await get('/hello'), 'hello-world');
    expect(await get('/api'), 'Hello World!');
    expect(await get('/api/'), 'Hello World!');
    expect(await get('/api/user/jonasfj/info'), 'Hello jonasfj');
    expect(await get('/api/user/jonasfj/info-wrong'), 'catch-all-handler');
  });

  test('responds with 404 if no handler matches', () {
    var api = Router()..get('/hello', (request) => Response.ok('Hello'));
    server.mount(api.call);

    expect(
        get('hi'),
        throwsA(isA<http.ClientException>()
            .having((e) => e.message, 'message', contains('404: Not Found.'))));
  });

  test('can invoke custom handler if no route matches', () {
    var api = Router(notFoundHandler: (req) => Response.ok('Not found, but ok'))
      ..get('/hello', (request) => Response.ok('Hello'));
    server.mount(api.call);

    expect(get('/hi'), completion('Not found, but ok'));
  });

  test('can call Router.routeNotFound.read multiple times', () async {
    final b1 = await Router.routeNotFound.readAsString();
    expect(b1, 'Route not found');
    final b2 = await Router.routeNotFound.readAsString();
    expect(b2, b1);
  });

  test('smart trailing slash matching is strict by default', () async {
    var app = Router();

    app.get('/no-slash', (Request request) => Response.ok('no-slash'));
    app.get('/with-slash/', (Request request) => Response.ok('with-slash'));

    server.mount(app.call);

    // Exact matches
    expect(await get('/no-slash'), 'no-slash');
    expect(await get('/with-slash/'), 'with-slash');

    // Strict matches (no flexible trailing slash)
    expect(
        get('no-slash/'),
        throwsA(isA<http.ClientException>()
            .having((e) => e.message, 'message', contains('404'))));
    expect(
        get('with-slash'),
        throwsA(isA<http.ClientException>()
            .having((e) => e.message, 'message', contains('404'))));
  });

  test('hop tracking', () async {
    var api = Router();
    api.get('/info', (Request request) {
      final hops = request.context['shelf_router.hops'] as int;
      return Response.ok('api-hops:$hops');
    });

    var app = Router();
    app.get('/hello', (Request request) {
      final hops = request.context['shelf_router.hops'] as int;
      return Response.ok('hello-hops:$hops');
    });
    app.mount('/api/', api.call);

    server.mount(app.call);

    // /hello is 1 segment after / -> 1 hop
    expect(await get('/hello'), 'hello-hops:1');

    // /api/info
    // /api is 1 hop in 'app'
    // /:*path is 1 hop in 'app' (implementation of mount)
    // /info is 1 hop in 'api'
    // Total should be 3
    expect(await get('/api/info'), 'api-hops:3');
  });

  test('deprecated <param> and regex syntax', () async {
    var app = Router();
    // ignore: deprecated_member_use_from_same_package
    app.get(
        '/user/<name>', (Request request, String name) => Response.ok(name));
    // ignore: deprecated_member_use_from_same_package
    app.get('/ref/<id|\\d+>',
        (Request request, String id) => Response.ok('id:$id'));

    server.mount(app.call);

    expect(await get('/user/alice'), 'alice');
    expect(await get('/ref/123'), 'id:123');
  });

  test('deprecated catch-all syntax', () async {
    var app = Router();
    // ignore: deprecated_member_use_from_same_package
    app.all('/static/<file|[^]*>',
        (Request request, String file) => Response.ok(file));
    // ignore: deprecated_member_use_from_same_package
    app.all('/any/<*>', (Request request, String any) => Response.ok(any));

    server.mount(app.call);

    // Use a helper to avoid double slash issues if any
    Future<String> getAbs(String path) => http.read(server.url.resolve(path));

    expect(await getAbs('static/path/to/file.txt'), 'path/to/file.txt');
    expect(await getAbs('any/foo/bar'), 'foo/bar');
  });

  test('conflicting parameter names throw exception', () {
    var app = Router();
    app.get('/:id', (Request request) => Response.ok('ok'));
    expect(
        () => app.get('/:name', (Request request) => Response.ok('ok')),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message',
            contains('Conflicting parameter names'))));
  });

  test('inspectTree and printRoutes', () {
    var app = Router();
    app.get('/hello', (Request request) => Response.ok('ok'));
    var api = Router();
    api.get('/version', (Request request) => Response.ok('1'));
    app.mount('/api', api);

    final tree = app.inspectTree();
    expect(tree, contains('hello (HEAD, GET)'));
    expect(tree, contains('api (ALL)'));
    expect(tree, contains('version (HEAD, GET)'));

    // printRoutes just calls inspectTree, but we call it for coverage
    expect(() => app.printRoutes(), prints(contains('hello')));
  });

  test('HEAD request and _removeBody', () async {
    var app = Router();
    app.get(
        '/data',
        (Request request) =>
            Response.ok('some-large-body', headers: {'content-length': '15'}));

    server.mount(app.call);

    final response = await http.head(server.url.resolve('data'));
    expect(response.statusCode, 200);
    expect(response.body, isEmpty);
    // _removeBody should set content-length to '0' or shelf might remove it
    expect(response.headers['content-length'], anyOf('0', null));
  });

  test('mount variations', () async {
    var app = Router();
    var sub = Router()..get('/hi', (Request request) => Response.ok('hi'));

    app.mount('/a', sub);
    app.mount('/b/', sub);

    server.mount(app.call);

    expect(await get('/a/hi'), 'hi');
    expect(await get('/b/hi'), 'hi');
  });

  test('deprecated params function', () async {
    var app = Router();
    app.get('/user/:name', (Request request) {
      // ignore: deprecated_member_use_from_same_package
      final name = params(request, 'name');
      return Response.ok(name);
    });

    server.mount(app.call);
    expect(await get('user/bob'), 'bob');

    // Test exception case
    final request = Request('GET', server.url.resolve('/'));
    // ignore: deprecated_member_use_from_same_package
    expect(() => params(request, 'non-existent'), throwsA(isA<Exception>()));
  });

  test('Route and Use annotations (smoke test)', () {
    // Just instantiate them to get coverage on the constructors
    const r1 = Route('GET', '/');
    expect(r1.verb, 'GET');
    const r2 = Route.all('/');
    expect(r2.verb, r'$all');
    const r3 = Route.get('/');
    expect(r3.verb, 'GET');
    const r4 = Route.head('/');
    expect(r4.verb, 'HEAD');
    const r5 = Route.post('/');
    expect(r5.verb, 'POST');
    const r6 = Route.put('/');
    expect(r6.verb, 'PUT');
    const r7 = Route.delete('/');
    expect(r7.verb, 'DELETE');
    const r8 = Route.connect('/');
    expect(r8.verb, 'CONNECT');
    const r9 = Route.options('/');
    expect(r9.verb, 'OPTIONS');
    const r10 = Route.trace('/');
    expect(r10.verb, 'TRACE');
    const r11 = Route.mount('/api');
    expect(r11.verb, r'$mount');

    //TODO: find a way to test Use annotation
  });

  test('empty catch-all', () async {
    var app = Router();
    app.get('/static/:*path', (Request request) {
      return Response.ok('path:${request.params['path']}');
    });

    server.mount(app.call);

    expect(await get('static/foo'), 'path:foo');
    expect(await get('static'), 'path:');
    expect(await get('static/'), 'path:');
  });

  test('complex tree dump with merged slash', () {
    var app = Router();
    app.get('/hello', (Request request) => Response.ok('ok'));
    app.get('/hello/', (Request request) => Response.ok('ok-slash'));
    app.get('/hello/world', (Request request) => Response.ok('ok-world'));

    final tree = app.inspectTree();
    expect(tree, contains('hello [/] (HEAD, GET)'));
    expect(tree, contains('└── world (HEAD, GET)'));
  });

  test('mount prefix fallback behavior', () async {
    var app = Router();
    // Use the actual pattern mount uses for prefixes
    app.all('/api/:*path', (Request request) {
      return Response.ok('api-prefix:${request.params['path']}');
    });

    // Most specific route matches first
    app.get('/api/info', (Request request) => Response.ok('info'));

    server.mount(app.call);

    expect(await get('api/info'), 'info');
    expect(await get('api/other'), 'api-prefix:other');
    expect(await get('api/'), 'api-prefix:');
  });

  test('inspectTree with empty childDump', () {
    var app = Router();
    // Handler with childDump that returns empty
    app.add('GET', '/empty', (r) => Response.ok(''), childDump: (i) => '');
    expect(app.inspectTree(), contains('empty (HEAD, GET)'));
  });
}
