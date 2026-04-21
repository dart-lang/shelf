import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

void main(List<String> args) async {
  final handler = const Pipeline().addMiddleware(logRequests()).addHandler((
    Request request,
  ) {
    return Response.ok('Echo: ${request.requestedUri.path}');
  });

  // Bind to 127.0.0.1 to avoid resolution issues
  final server = await shelf_io.serve(handler, '127.0.0.1', 0);
  print('Serving at port: ${server.port}');
}
