// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library shelf_static.test_util;

import 'dart:async';

import 'package:shelf/shelf.dart';
import 'package:shelf_static/src/util.dart';

/// Makes a simple GET request to [handler] and returns the result.
Future<Response> makeRequest(Handler handler, String path) =>
    syncFuture(() => handler(_fromPath(path)));

Request _fromPath(String path) => new Request(path, '', 'GET', '', '1.1',
    Uri.parse('http://localhost' + path), {});
