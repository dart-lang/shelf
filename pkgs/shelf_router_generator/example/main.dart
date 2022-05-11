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

// @dart=2.12

import 'dart:async' show Future;

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

// Generated code will be written to 'main.g.dart'
part 'main.g.dart';

class Service {
  // A handler is annotated with @Route.<verb>('<route>'), the '<route>' may
  // embed URL-parameters, and these may be taken as parameters by the handler.
  // But either all URL-parameters or none of the URL parameters must be taken
  // as parameters by the handler.
  @Route.get('/say-hi/<name>')
  Response _hi(Request request, String name) => Response.ok('hi $name');

  // Embedded URL parameters may also be associated with a regular-expression
  // that the pattern must match.
  @Route.get('/user/<userId|[0-9]+>')
  Response _user(Request request, String userId) =>
      Response.ok('User has the user-number: $userId');

  // Handlers can be asynchronous (returning `FutureOr` is also allowed).
  @Route.get('/wave')
  Future<Response> _wave(Request request) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return Response.ok('_o/');
  }

  // Other routers can be mounted...
  @Route.mount('/api/')
  Router get _api => Api().router;

  // You can catch all verbs and use a URL-parameter with a regular expression
  // that matches everything to catch app.
  @Route.all('/<ignored|.*>')
  Response _notFound(Request request) => Response.notFound('Page not found');

  // The generated function _$ServiceRouter can be used to get a [Handler]
  // for this object. This can be used with [shelf_io.serve].
  Handler get handler => _$ServiceRouter(this);
}

class Api {
  // A handler can have more that one route :)
  @Route.get('/messages')
  @Route.get('/messages/')
  Future<Response> _messages(Request request) async => Response.ok('[]');

  // This nested catch-all, will only catch /api/.* when mounted above.
  // Notice that ordering if annotated handlers and mounts is significant.
  @Route.all('/<ignored|.*>')
  Response _notFound(Request request) => Response.notFound('null');

  // The generated function _$ApiRouter can be used to expose a [Router] for
  // this object.
  Router get router => _$ApiRouter(this);
}

// Run shelf server and host a [Service] instance on port 8080.
void main() async {
  final service = Service();
  final server = await shelf_io.serve(service.handler, 'localhost', 8080);
  print('Server running on localhost:${server.port}');
}
