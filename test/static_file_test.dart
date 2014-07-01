library shelf_proxy.static_file_test;

import 'dart:async';
import 'dart:io';

import 'package:scheduled_test/scheduled_test.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart' as shelf_static;
import 'package:shelf_proxy/shelf_proxy.dart';

import 'test_util.dart';

void main() {
  test('foo', () {
    _scheduleServer(_handler);

    schedule(() {
      var url = new Uri.http('localhost:$_serverPort', '');
      var handler = createProxyHandler(url);

      return makeRequest(handler, '/').then((response) {
        expect(response.statusCode, HttpStatus.OK);
        expect(response.readAsString(),
            completion(contains('<title>shelf_static</title>')));
        expect(response.contentLength, isNotNull);
      });
    });
  });
}

final _handler = shelf_static.createStaticHandler('test/test_files',
    defaultDocument: 'index.html');

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
