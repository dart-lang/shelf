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
import 'dart:io' show HttpServer;

import 'package:shelf/shelf_io.dart' as shelf_io;

import 'service.dart';

class Server {
  final _service = Service();
  late HttpServer _server;

  Future<void> start() async {
    _server = await shelf_io.serve(_service.router, 'localhost', 0);
  }

  Future<void> stop() => _server.close();

  Uri get uri => Uri(
        scheme: 'http',
        host: 'localhost',
        port: _server.port,
      );
}
