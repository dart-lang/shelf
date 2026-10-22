import 'dart:convert';
import 'dart:io';

/// Plain dart:io HttpServer — the ceiling for any HttpServer-based adapter
/// (no shelf involved). Supports `/`, `/plaintext`, `/json`, and `/user/<id>`.
void main(List<String> args) async {
  final server = await HttpServer.bind('127.0.0.1', 8083);
  print('dart:io Server listening on 8083');
  await for (final request in server) {
    final path = request.uri.path;
    if (path == '/' || path == '/plaintext') {
      request.response
        ..headers.contentType = ContentType.text
        ..write('hello world');
    } else if (path == '/json') {
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'message': 'Hello, World!'}));
    } else if (path.startsWith('/user/')) {
      final id = path.substring(6);
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'id': id, 'name': 'User $id'}));
    } else {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not Found');
    }
    await request.response.close();
  }
}
