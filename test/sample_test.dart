library shelf_static.sample_test;

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
      return _testFileContents('index.html');
    });

    test('mimeType is text/html', () {
      return _requestFile('index.html').then((response) {
        expect(response.mimeType, 'text/html');
      });
    });
  });

  group('/favicon.ico', () {
    test('body is correct', () {
      return _testFileContents('favicon.ico');
    });

    test('mimeType is text/html', () {
      return _requestFile('favicon.ico').then((response) {
        expect(response.mimeType, 'image/x-icon');
      });
    });
  });
}

Future<Response> _requestFile(String filename) {
  var uri = Uri.parse('http://localhost/$filename');

  return _request(new Request('GET', uri));
}

Future _testFileContents(String filename) {
  var filePath = p.join(_samplePath, filename);
  var file = new File(filePath);
  var fileContents = file.readAsBytesSync();
  var fileStat = file.statSync();

  return _requestFile(filename).then((response) {
    expect(response.contentLength, fileStat.size);
    expect(response.lastModified, fileStat.changed.toUtc());
    return _expectCompletesWithBytes(response, fileContents);
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
  var sampleDir = p.join(p.current, 'example', 'files');
  assert(FileSystemEntity.isDirectorySync(sampleDir));
  return sampleDir;
}
