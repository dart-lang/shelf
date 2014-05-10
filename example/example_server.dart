library shelf_static.example;

import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

void main() {
  if (!FileSystemEntity.isFileSync('example/example_server.dart')) {
    throw new StateError('Server expects to be started the '
        'root of the project.');
  }
  var handler = const shelf.Pipeline().addMiddleware(shelf.logRequests())
      .addHandler(createStaticHandler('example/files'));

  io.serve(handler, 'localhost', 8080).then((server) {
    print('Serving at http://${server.address.host}:${server.port}');
  });
}
