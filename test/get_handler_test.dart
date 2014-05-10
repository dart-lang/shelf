library shelf_static.get_handler_test;

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_test.dart';

import 'package:shelf_static/shelf_static.dart';

void main() {
  setUp(() {
    var tempDir;
    schedule(() {
      return Directory.systemTemp.createTemp('shelf_static-test-').then((dir) {
        tempDir = dir;
        d.defaultRoot = tempDir.path;
      });
    });

    d.file('root.txt', 'root txt').create();
    d.dir('files', [
        d.file('test.txt', 'test txt content'),
        d.file('with space.txt', 'with space content')
    ]).create();

    currentSchedule.onComplete.schedule(() {
      d.defaultRoot = null;
      return tempDir.delete(recursive: true);
    });
  });

  test('non-existent relative path', () {
    schedule(() {
      expect(() => getHandler('random/relative'), throwsArgumentError);
    });
  });

  test('existing relative path', () {
    schedule(() {
      var existingRelative = p.relative(d.defaultRoot);
      expect(() => getHandler(existingRelative), returnsNormally);
    });
  });

  test('non-existent absolute path', () {
    schedule(() {
      var nonExistingAbsolute = p.join(d.defaultRoot, 'not_here');
      expect(() => getHandler(nonExistingAbsolute), throwsArgumentError);
    });
  });

  test('existing absolute path', () {
    schedule(() {
      expect(() => getHandler(d.defaultRoot), returnsNormally);
    });
  });
}
