`shelf_static` is a `Handler` for the Dart `shelf` package.

[![Build Status](https://travis-ci.org/dart-lang/shelf_static.svg?branch=master)](https://travis-ci.org/dart-lang/shelf_static?branch=master)

### Example
```dart
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

void main() {
  var handler = createStaticHandler('example/files', 
      defaultDocument: 'index.html');

  io.serve(handler, 'localhost', 8080);
}
```
