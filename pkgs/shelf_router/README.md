# Web Request Router for Shelf

[Shelf][shelf] makes it easy to build web
applications in Dart by composing request handlers. This package offers a
request router for Shelf, matching request to handlers using route patterns.

**Disclaimer:** This is not an officially supported Google product.

Also see the [`shelf_router_generator`][shelf_router_generator] package
for how to automatically generate
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

var server = await io.serve(app, 'localhost', 8080);
```

See reference documentation of `Router` class for more information.

## See also
 * Package [`shelf`][shelf] for which this package can create routers.
 * Package [`shelf_router_generator`][shelf_router_generator] which can generate
   a router using source code annotations.
 * Third-party tutorial by [creativebracket.com]:
   * Video: [Build RESTful Web APIs with shelf_router][1]
   * Sample: [repository for tutorial][2]

[shelf]: https://pub.dev/packages/shelf
[shelf_router_generator]: https://pub.dev/packages/shelf_router_generator
[creativebracket.com]: https://creativebracket.com/
[1]: https://www.youtube.com/watch?v=v7FhaV9e3yY
[2]: https://github.com/graphicbeacon/shelf_router_api_tutorial
