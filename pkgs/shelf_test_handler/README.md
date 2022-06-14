[![pub package](https://img.shields.io/pub/v/shelf_test_handler.svg)](https://pub.dev/packages/shelf_test_handler)
[![package publisher](https://img.shields.io/pub/publisher/shelf_test_handler.svg)](https://pub.dev/packages/shelf_test_handler/publisher)

A [shelf][] handler that makes it easy to test HTTP interactions, especially
when multiple different HTTP requests are expected in a particular sequence.

[shelf]: [https://github.com/dart-lang/shelf#readme]

You can construct a [ShelfTestHandler][] directly, but most users will probably
want to use the [ShelfTestServer][] instead. This wraps the handler in a simple
HTTP server, whose URL can be passed to client code.

[ShelfTestHandler]: https://www.dartdocs.org/documentation/shelf_test_handler/latest/shelf_test_handler/ShelfTestHandler-class.html
[ShelfTestServer]: https://www.dartdocs.org/documentation/shelf_test_handler/latest/shelf_test_handler/ShelfTestServer-class.html

```dart
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_test_handler/shelf_test_handler.dart';
import 'package:test/test.dart';

import 'package:my_package/my_package.dart';

void main() {
  test("client performs protocol handshake", () async {
    // This is just a utility class that starts a server for a ShelfTestHandler.
    var server = new ShelfTestServer();

    // Asserts that the client will make a GET request to /token.
    server.handler.expect("GET", "/token", (request) async {
      // This handles the GET /token request.
      var body = JSON.parse(await request.readAsString());

      // Any failures in this handler will cause the test to fail, so it's safe
      // to make assertions.
      expect(body, containsPair("id", "my_package_id"));
      expect(body, containsPair("secret", "123abc"));

      return new shelf.Response.ok(JSON.encode({"token": "a1b2c3"}),
          headers: {"content-type": "application/json"});
    });

    // Requests made against `server.url` will be handled by the handlers we
    // declare.
    var myPackage = new MyPackage(server.url);

    // If the client makes any unexpected requests, the test will fail.
    await myPackage.performHandshake();
  });
}
```
