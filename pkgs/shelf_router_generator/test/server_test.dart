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

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'server/server.dart';

void main() {
  final server = Server();
  setUpAll(server.start);
  tearDownAll(server.stop);

  void testGet({
    required String path,
    required String result,
  }) =>
      test('GET $path', () async {
        final result = await http.get(server.uri.resolve(path));
        expect(result, equals(result));
      });

  // Test simple handlers
  testGet(path: '/say-hello', result: 'hello world');
  testGet(path: '/say-hello/', result: 'hello world');
  testGet(path: '/wave', result: '_o/');
  testGet(path: '/greet/jonasfj', result: 'Greetings, jonasfj');
  testGet(path: '/greet/sigurdm', result: 'Greetings, sigurdm');
  testGet(path: '/hi/jonasfj', result: 'hi jonasfj');
  testGet(path: '/hi/sigurdm', result: 'hi sigurdm');

  // Test /api/
  testGet(path: '/api/time', result: 'it is about now');
  testGet(path: '/api/to-uppercase/wEiRd%20Word', result: 'WEIRD WORD');
  testGet(path: '/api/to-uppercase/wEiRd Word', result: 'WEIRD WORD');

  // Test the catch all handler
  testGet(path: '/', result: 'nothing-here');
  testGet(path: '/wrong-path', result: 'nothing-here');
  testGet(path: '/hi/sigurdm/ups', result: 'nothing-here');
  testGet(path: '/api/to-uppercase/too/many/slashs', result: 'nothing-here');
  testGet(path: '/api/', result: 'nothing-here');
  testGet(path: '/api/time/', result: 'nothing-here'); // notice the extra slash
  testGet(path: '/api/tim', result: 'nothing-here');
}
