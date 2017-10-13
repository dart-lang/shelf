library shelf_static.example;

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_proxy/shelf_proxy.dart';

const _PUB_PORT = 7777;
final _encoder = new JsonEncoder.withIndent('  ');

void main() {
  //
  // The api handler responds to requests to '/api' with a JSON document
  // containing an incrementing 'count' value.
  //
  int apiCount = 0;
  var apiHandler = (Request request) {
    if (request.url.path == '/api') {
      apiCount++;
      var json = _encoder.convert({'count': apiCount});
      var headers = {'Content-Type': 'application/json'};
      return new Response.ok(json, headers: headers);
    }

    return new Response.notFound('');
  };

  //
  // Cascade sends requests to `apiHandler` first. If that handler returns a
  // 404, the request is next sent to the proxy handler pointing at pub
  //
  var cascade = new Cascade()
      .add(apiHandler)
      .add(proxyHandler(Uri.parse('http://localhost:$_PUB_PORT')));

  //
  // Creates a pipeline handler which first logs requests and then sends them
  // to the cascade.
  //
  var handler =
      const Pipeline().addMiddleware(logRequests()).addHandler(cascade.handler);

  //
  // Serve the combined handler on localhost at port 8080.
  //
  io.serve(handler, 'localhost', 8080).then((server) {
    print('Serving at http://${server.address.host}:${server.port}');
    print('`pub serve` should be running at port $_PUB_PORT '
        'on the example dir.');
    print('  command: pub serve --port $_PUB_PORT example/');
  });
}
