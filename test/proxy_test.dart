library shelf_proxy.proxy_test;

import 'dart:async';
import 'dart:io';

import 'package:scheduled_test/scheduled_test.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_proxy/shelf_proxy.dart';

import 'test_util.dart';

void main() {
  test('root', () {
    _scheduleServer(_handler);

    schedule(() {
      var url = new Uri.http('localhost:$_serverPort', '');
      var handler = createProxyHandler(url);

      return makeRequest(handler, '/').then((response) {
        expect(response.statusCode, HttpStatus.OK);
        expect(response.readAsString(), completion('root with slash'));
      });
    });
  });

  test('bar', () {
    _scheduleServer(_handler);

    schedule(() {
      var url = new Uri.http('localhost:$_serverPort', '');
      var handler = createProxyHandler(url);

      return makeRequest(handler, '/bar').then((response) {
        expect(response.statusCode, HttpStatus.OK);
        expect(response.readAsString(), completion('bar'));
      });
    });
  });

  test('bar/', () {
    _scheduleServer(_handler);

    schedule(() {
      var url = new Uri.http('localhost:$_serverPort', '');
      var handler = createProxyHandler(url);

      return makeRequest(handler, '/bar/').then((response) {
        expect(response.statusCode, HttpStatus.OK);
        expect(response.readAsString(), completion('bar with slash'));
      });
    });
  });
}

Response _handler(Request request) {
  if (request.method != 'GET') {
    return new Response.forbidden("I don't like method ${request.method}.");
  }

  String content;
  switch (request.url.path) {
    case '':
      content = 'root';
      break;
    case '/':
      content = 'root with slash';
      break;
    case '/bar':
      content = 'bar';
      break;
    case '/bar/':
      content = 'bar with slash';
      break;
    default:
      return new Response.notFound("I don't like '${request.url.path}'.");
  }
  return new Response.ok(content);
}

int _serverPort;

Future _scheduleServer(Handler handler) {
  return schedule(() => shelf_io.serve(handler, 'localhost', 0).then((server) {
    currentSchedule.onComplete.schedule(() {
      _serverPort = null;
      return server.close(force: true);
    });

    _serverPort = server.port;
  }));
}
