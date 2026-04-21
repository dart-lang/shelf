import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

void main(List<String> args) async {
  final handler = const Pipeline().addMiddleware(logRequests()).addHandler((
    Request request,
  ) async {
    final path = request.requestedUri.path;

    // Echo body back for /echo
    if (path == '/echo' || path == '/echo/') {
      final body = await request.readAsString();
      final cookie = request.headers['cookie'];

      final buffer = StringBuffer()..write(body);
      if (cookie != null) {
        buffer.writeln();
        buffer.write('Cookie: $cookie');
      }

      return Response.ok(buffer.toString());
    }

    // Default fallback for other tests
    return Response.ok('Echo: $path');
  });

  // Bind to 127.0.0.1 to avoid resolution issues
  final server = await shelf_io.serve(handler, '127.0.0.1', 0);
  print('Serving at port: ${server.port}');
}
