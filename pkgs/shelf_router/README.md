[![pub package](https://img.shields.io/pub/v/shelf_router.svg)](https://pub.dev/packages/shelf_router)
[![package publisher](https://img.shields.io/pub/publisher/shelf_router.svg)](https://pub.dev/packages/shelf_router/publisher)

## Web Request Router for Shelf

[Shelf][shelf] makes it easy to build web
applications in Dart by composing request handlers. This package offers a
request router for Shelf, matching request to handlers using route patterns.

Also see the [`shelf_router_generator`][shelf_router_generator] package
for how to automatically generate
a `Route` using the `Route` annotation in this package.

## Example

```dart
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

// instantiate a router and configure your routes
var router = Router();

router.get('/hello', (Request request) {
  return Response.ok('hello-world');
});

router.get('/user/<user>', (Request request, String user) {
  return Response.ok('hello $user');
});

// use a Pipeline to configure your middleware,
// then add the router as the handler
final app = const Pipeline()
  .addMiddleware(logRequests())
  .addMiddleware(logHops()) // Log trie hops for each request
  .addHandler(router.call);

var server = await io.serve(app, 'localhost', 8080);
```

### Route Hops

The router tracks the number of trie nodes (hops) traversed during route matching. This is useful for debugging and performance monitoring. You can access the hop count from the `Response.context['shelf_router.hops']` or use the included `logHops()` middleware.

```dart
final app = const Pipeline()
  .addMiddleware(logHops((message) => print('HOPS: $message')))
  .addHandler(router.call);
```

### Trailing Slash Handling

By default, the router is strict and treats `/hello` and `/hello/` as distinct paths. To allow flexible matching where trailing slashes are automatically handled, you can use the `removeTrailingSlash()` middleware.

```dart
final app = const Pipeline()
  .addMiddleware(removeTrailingSlash())
  .addHandler(router.call);
```

When used at the beginning of your pipeline, it normalizes incoming requests by stripping trailing slashes, ensuring they match routes defined without one.

See reference documentation of `Router` class for more information.

## Performance

The new Trie-based routing engine provides significant performance improvements over the traditional regex-based approach, especially for large APIs.

### Benchmarks (10,000 Routes)

Measured on a worst-case match (the last route defined) and a 404 (route not found).

| Metric | New Engine (Trie) | Improvement |
|--------|-------------------|-------------|
| **Worst-Case Match** | **~19μs** | **~10x Faster** |
| **404 (Not Found)** | **~0.7μs** | **~100x+ Faster** |

The Trie-based engine has **O(L)** complexity (where L is the path depth), compared to the **O(N)** complexity (where N is the total number of routes) of the previous implementation. This means your routing overhead remains constant even as your API grows to thousands of routes.

You can run the benchmarks yourself:
```bash
dart benchmark/routing_benchmark.dart
```

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
