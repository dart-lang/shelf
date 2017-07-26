// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:shelf/shelf.dart';

// "hello,"
const helloBytes = const [104, 101, 108, 108, 111, 44];

// " world"
const worldBytes = const [32, 119, 111, 114, 108, 100];

/// A simple, synchronous handler for [Request].
///
/// By default, replies with a status code 200, empty headers, and
/// `Hello from ${request.url.path}`.
Response syncHandler(Request request,
    {int statusCode, Map<String, String> headers}) {
  if (statusCode == null) statusCode = 200;
  return new Response(statusCode,
      headers: headers, body: 'Hello from ${request.requestedUri.path}');
}

/// Calls [syncHandler] and wraps the response in a [Future].
Future<Response> asyncHandler(Request request) =>
    new Future(() => syncHandler(request));

/// Makes a simple GET request to [handler] and returns the result.
Future<Response> makeSimpleRequest(Handler handler) =>
    new Future.sync(() => handler(_request));

final _request = new Request('GET', localhostUri);

final localhostUri = Uri.parse('http://localhost/');
