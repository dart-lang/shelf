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
import 'package:shelf_router/shelf_router.dart';

part 'api.g.dart';

class Api {
  @Route.get('/time')
  Response _time(Request request) => Response.ok('it is about now');

  @Route.get('/to-uppercase/<word|.*>')
  Future<Response> _toUpperCase(Request request, String word) async =>
      Response.ok(word.toUpperCase());

  @Route.get(r'/$string-escape')
  Response _stringEscapingWorks(Request request) =>
      Response.ok('Just testing string escaping');

  Router get router => _$ApiRouter(this);
}
