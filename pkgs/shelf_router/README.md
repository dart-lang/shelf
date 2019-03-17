# Web Request Router for Shelf

[Shelf](https://pub.dartlang.org/packages/shelf) makes it easy to build web
applications in Dart by composing request handlers. This package offers a
request router for Shelf, matching request to handlers using route patterns.

**Disclaimer:** This is not an officially supported Google product.

Also see the `shelf_router_generator` package for how to automatically generate
a `Route` using the `Route` annotation in this package.

## Example

```dart
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

var app = Router();

app.get('/hello', (Request request) {
  return Response.ok('hello-world');
});

app.get('/user/<user>', (Request request, String user) {
  return Response.ok('hello $user');
});

var server = await io.serve(app.handler, 'localhost', 8080);
```

See reference documentation of `Router` class for more information.

