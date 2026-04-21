import 'dart:async';

import 'package:bottom_shelf/bottom_shelf.dart';
import 'package:bottom_shelf/src/constants.dart';
import 'package:shelf/shelf.dart';

void main(List<String> args) async {
  final handler = const Pipeline()
      .addMiddleware(_typedHeaderMiddleware)
      .addHandler(_handleRequest);

  await RawShelfServer.serve(handler, 'localhost', 8081);
  print('Raw Server listening on 8081');
}

/// A middleware that simulates real-world usage of typed headers.
Handler _typedHeaderMiddleware(Handler innerHandler) => (request) {
  final typed = request.context[$Context.rawHeaders] as TypedHeaders?;
  // Access a header multiple times to benefit from caching
  final _ = typed?.ifModifiedSince;
  final _ = typed?.contentType;
  return innerHandler(request);
};

Future<Response> _handleRequest(Request request) async =>
    Response.ok('hello world');
