import 'dart:io';

/// Plain dart:io HttpServer "hello world" — the ceiling for any
/// HttpServer-based adapter (no shelf involved).
void main(List<String> args) async {
  final server = await HttpServer.bind('127.0.0.1', 8083);
  print('dart:io Server listening on 8083');
  await for (final request in server) {
    request.response
      ..headers.contentType = ContentType.text
      ..write('hello world');
    await request.response.close();
  }
}
