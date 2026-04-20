import 'dart:async';
import 'package:shelf/shelf.dart';
import 'package:bottom_shelf/bottom_shelf.dart';

void main(List<String> args) async {
  final handler = const Pipeline()
      .addMiddleware(_typedHeaderMiddleware)
      .addHandler(_handleRequest);

  await RawShelfServer.serve(handler, 'localhost', 8081);
  print('Raw Server listening on 8081');
}

/// A middleware that simulates real-world usage of typed headers.
Handler _typedHeaderMiddleware(Handler innerHandler) {
  return (request) {
    final typed = request.context['shelf.raw.headers'] as TypedHeaders?;
    // Access a header multiple times to benefit from caching
    final _ = typed?.ifModifiedSince;
    final _ = typed?.contentType;
    return innerHandler(request);
  };
}

Future<Response> _handleRequest(Request request) async {
  return Response.ok('hello world');
}
