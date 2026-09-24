import 'dart:async';
import 'dart:convert';

import 'package:bottom_shelf/bottom_shelf.dart';
import 'package:bottom_shelf/src/constants.dart';
import 'package:shelf/shelf.dart';

void main(List<String> args) async {
  final handler = const Pipeline()
      .addMiddleware(_typedHeaderMiddleware)
      .addHandler(_handleRequest);

  await RawShelfServer.serve(handler, '127.0.0.1', 8081);
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

FutureOr<Response> _handleRequest(Request request) {
  final path = request.url.path;
  if (path.isEmpty || path == 'plaintext') {
    return Response.ok('hello world');
  }
  if (path == 'json') {
    return Response.ok(
      jsonEncode({'message': 'Hello, World!'}),
      headers: {'content-type': 'application/json'},
    );
  }
  if (path.startsWith('user/')) {
    final id = path.substring(5);
    return Response.ok(
      jsonEncode({'id': id, 'name': 'User $id'}),
      headers: {'content-type': 'application/json'},
    );
  }
  return Response.notFound('Not Found');
}
