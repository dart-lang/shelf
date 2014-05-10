`shelf_static` is a `Handler` for the Dart `shelf` package.

[![Build Status](https://drone.io/github.com/kevmoo/shelf_static.dart/status.png)](https://drone.io/github.com/kevmoo/shelf_static.dart/latest)


### Example
```
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

void main() {
  var handler = createStaticHandler('files');

  io.serve(handler, 'localhost', 8080);
}
```
