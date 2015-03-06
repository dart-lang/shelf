`shelf_static` is a `Handler` for the Dart `shelf` package.

[![Build Status](https://travis-ci.org/kevmoo/shelf_static.dart.svg?branch=master)](https://travis-ci.org/kevmoo/shelf_static.dart?branch=master)
[![Coverage Status](https://coveralls.io/repos/kevmoo/shelf_static.dart/badge.svg?branch=master)](https://coveralls.io/r/kevmoo/shelf_static.dart?branch=master)


### Example
```
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

void main() {
  var handler = createStaticHandler('example/files', 
      defaultDocument: 'index.html');

  io.serve(handler, 'localhost', 8080);
}
```
