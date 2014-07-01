// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library shelf_proxy.test_util;

import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_proxy/src/util.dart';

final p.Context _ctx = p.url;

/// Makes a simple GET request to [handler] and returns the result.
Future<Response> makeRequest(Handler handler, String path,
    {String scriptName, Map<String, String> headers, String method}) {
  var rootedHandler = _rootHandler(scriptName, handler);
  return syncFuture(() =>
      rootedHandler(_fromPath(path, headers, method: method)));
}

Request _fromPath(String path, Map<String, String> headers, {String method}) {
  if (method == null) method = 'GET';
  return new Request(method, Uri.parse('http://localhost' + path),
      headers: headers);
}

Handler _rootHandler(String scriptName, Handler handler) {
  if (scriptName == null || scriptName.isEmpty) {
    return handler;
  }

  if (!scriptName.startsWith('/')) {
    throw new ArgumentError('scriptName must start with "/" or be empty');
  }

  return (Request request) {
    if (!_ctx.isWithin(scriptName, request.requestedUri.path)) {
      return new Response.notFound('not found');
    }
    assert(request.scriptName.isEmpty);

    var relativeRequest = request.change(scriptName: scriptName);

    return handler(relativeRequest);
  };
}
