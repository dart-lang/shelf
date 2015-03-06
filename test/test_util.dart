// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library shelf_static.test_util;

import 'dart:async';

import 'package:matcher/matcher.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_static/src/util.dart';

final p.Context _ctx = p.url;

/// Makes a simple GET request to [handler] and returns the result.
Future<Response> makeRequest(Handler handler, String path,
    {String scriptName, Map<String, String> headers}) {
  var rootedHandler = _rootHandler(scriptName, handler);
  return new Future.sync(() => rootedHandler(_fromPath(path, headers)));
}

Request _fromPath(String path, Map<String, String> headers) =>
    new Request('GET', Uri.parse('http://localhost' + path), headers: headers);

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

Matcher atSameTimeToSecond(value) =>
    new _SecondResolutionDateTimeMatcher(value);

class _SecondResolutionDateTimeMatcher extends Matcher {
  final DateTime _target;

  _SecondResolutionDateTimeMatcher(DateTime target)
      : this._target = toSecondResolution(target);

  bool matches(item, Map matchState) {
    if (item is! DateTime) return false;

    return datesEqualToSecond(_target, item);
  }

  Description describe(Description descirption) => descirption.add(
      'Must be at the same moment as $_target with resolution '
      'to the second.');
}

bool datesEqualToSecond(DateTime d1, DateTime d2) {
  return toSecondResolution(d1).isAtSameMomentAs(toSecondResolution(d2));
}
