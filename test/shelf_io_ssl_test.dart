// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
@TestOn('vm')
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as parser;
import 'package:scheduled_test/scheduled_stream.dart';
import 'package:scheduled_test/scheduled_test.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'ssl_certs.dart';
import 'test_util.dart';

final SecurityContext securityContext = new SecurityContext()
  ..setTrustedCertificatesBytes(certChainBytes)
  ..useCertificateChainBytes(certChainBytes)
  ..usePrivateKeyBytes(certKeyBytes, password: 'dartdart');

var client = new HttpClient(context: securityContext);

void main() {
  test('secure sync handler returns a value to the client', () {
    _scheduleServer(syncHandler, securityContext: securityContext);

    return _scheduleGet().then((req) async {
      var response = await req.close();
      expect(response.statusCode, HttpStatus.OK);
      response.transform(UTF8.decoder).listen((contents) {
        expect(contents, 'Hello from /');
      });
    });
  });

  test('secure async handler returns a value to the client', () {
    _scheduleServer(asyncHandler, securityContext: securityContext);

    return _scheduleGet().then((req) async {
      var response = await req.close();
      expect(response.statusCode, HttpStatus.OK);
      response.transform(UTF8.decoder).listen((contents) {
        expect(contents, 'Hello from /');
      });
    });
  });
}

int _serverPort;

Future _scheduleServer(Handler handler, {SecurityContext securityContext}) {
  return schedule(() => shelf_io
          .serve(handler, 'localhost', 0, securityContext: securityContext)
          .then((server) {
        currentSchedule.onComplete.schedule(() {
          _serverPort = null;
          return server.close(force: true);
        });

        _serverPort = server.port;
      }));
}

Future<HttpRequest> _scheduleGet() {
  return schedule/*<Future<HttpRequest>>*/(() {
    return client.getUrl(Uri.parse('https://localhost:$_serverPort/'));
  });
}
