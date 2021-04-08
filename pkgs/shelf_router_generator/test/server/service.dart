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

import 'dart:async' show Future, FutureOr;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'api.dart';
import 'unrelatedannotation.dart';

part 'service.g.dart';

class Service {
  @Route.get('/say-hello')
  @Route.get('/say-hello/')
  Response _sayHello(Request request) => Response.ok('hello world');

  @Route.get('/wave')
  FutureOr<Response> _wave(Request request) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return Response.ok('_o/');
  }

  @Route.get('/greet/<user>')
  Future<Response> _greet(Request request, String user) async =>
      Response.ok('Greetings, $user');

  @Route.get('/hi/<user>')
  Future<Response> _hi(Request request) async {
    final name = params(request, 'user');
    return Response.ok('hi $name');
  }

  @Route.mount('/api/')
  Router get _api => Api().router;

  @Route.all('/<_|.*>')
  Response _index(Request request) => Response.ok('nothing-here');

  Router get router => _$ServiceRouter(this);
}

class UnrelatedThing {
  @EndPoint.put('/api/test')
  Future<Response> unrelatedMethod(Request request) async =>
      Response.ok('hello world');
}
