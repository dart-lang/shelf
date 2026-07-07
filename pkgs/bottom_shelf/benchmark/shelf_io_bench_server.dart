import 'dart:async';

import 'package:bottom_shelf/bottom_shelf.dart';
import 'package:bottom_shelf/src/constants.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

void main(List<String> args) async {
  final handler = const Pipeline()
      .addMiddleware(_typedHeaderMiddleware)
      .addHandler(_handleRequest);

  await shelf_io.serve(handler, '127.0.0.1', 8082);
  print('shelf_io Server listening on 8082');
}

/// Identical middleware shape to raw_bench_server.dart; the typed headers
/// context entry is absent under shelf_io, so the lookups are no-ops.
Handler _typedHeaderMiddleware(Handler innerHandler) => (request) {
  final typed = request.context[$Context.rawHeaders] as TypedHeaders?;
  // Access a header multiple times to benefit from caching
  final _ = typed?.ifModifiedSince;
  final _ = typed?.contentType;
  return innerHandler(request);
};

Future<Response> _handleRequest(Request request) async =>
    Response.ok('hello world');
