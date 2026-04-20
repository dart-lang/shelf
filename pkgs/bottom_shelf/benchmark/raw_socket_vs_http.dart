import 'dart:async';
import 'dart:convert';
import 'dart:io';

final helloWorldResponse = utf8.encode('HTTP/1.1 200 OK\r\n'
    'Content-Type: text/plain\r\n'
    'Content-Length: 11\r\n'
    'Connection: keep-alive\r\n'
    '\r\n'
    'hello world');

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart raw_socket_vs_http.dart [raw|http]');
    return;
  }

  if (args[0] == 'raw') {
    await runRaw();
  } else {
    await runHttp();
  }
}

Future<void> runRaw() async {
  final server = await ServerSocket.bind('localhost', 8080, shared: true);
  print('Raw Socket Server listening on 8080');
  server.listen((socket) {
    socket.listen((data) {
      // Very crude parser: just look for end of headers
      // In a real app, we'd parse properly.
      // Here we just respond to every chunk as if it's a request (good enough for benchmarking GET /)
      socket.add(helloWorldResponse);
    }, onError: (e) => socket.destroy(), onDone: () => socket.destroy());
  });
}

Future<void> runHttp() async {
  final server = await HttpServer.bind('localhost', 8080, shared: true);
  print('HttpServer listening on 8080');
  server.listen((request) {
    request.response
      ..headers.contentType = ContentType.text
      ..contentLength = 11
      ..write('hello world')
      ..close();
  });
}
