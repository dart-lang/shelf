library shelf_static.basic_file_test;

import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:scheduled_test/scheduled_test.dart';

import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_static/src/util.dart';

void main() {
  group('/index.html', () {
    test('body is correct', () {
      var uri = Uri.parse('http://localhost/index.html');
      var filePath = p.join(_samplePath, 'index.html');
      var fileContents = new File(filePath).readAsStringSync();

      return _request(new Request('GET', uri)).then((response) {
        expect(response.readAsString(), completion(fileContents));
      });
    });

    // Content-Type:text/html
    // Date:Fri, 02 May 2014 22:29:02 GMT
  });

  group('/favicon.ico', () {
    test('body is correct', () {
      var uri = Uri.parse('http://localhost/favicon.ico');
      var filePath = p.join(_samplePath, 'favicon.ico');
      var fileContents = new File(filePath).readAsBytesSync();

      return _request(new Request('GET', uri)).then((response) {
        return _expectCompletesWithBytes(response, fileContents);
      });
    });

    // Content-Type: ???
    // Date:Fri, 02 May 2014 22:29:02 GMT
  });
}

Future _expectCompletesWithBytes(Response response, List<int> expectedBytes) {
  return response.read().toList().then((List<List<int>> bytes) {
    var flatBytes = bytes.expand((e) => e);
    expect(flatBytes, orderedEquals(expectedBytes));
  });
}

Future<Response> _request(Request request) {
  var handler = getHandler(_samplePath);

  return syncFuture(() => handler(request));
}

String get _samplePath {
  var scriptDir = p.dirname(p.fromUri(Platform.script));
  var sampleDir = p.join(scriptDir, 'sample_files');
  assert(FileSystemEntity.isDirectorySync(sampleDir));
  return sampleDir;
}
