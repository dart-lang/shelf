## Proxy for Shelf

[![Build Status](https://drone.io/github.com/dart-lang/shelf_proxy/status.png)](https://drone.io/github.com/dart-lang/shelf_proxy/latest)

`shelf_proxy` is a [Shelf][] handler that proxies requests to an external
server. It can be served directly and used as a proxy server, or it can be
mounted within a larger application to proxy only certain URLs.

[Shelf]: http://pub.dartlang.org/packages/shelf

```dart
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_proxy/shelf_proxy.dart';

void main() {
  shelf_io.serve(proxyHandler("https://www.dartlang.org"), 'localhost', 8080)
      .then((server) {
    print('Proxying at http://${server.address.host}:${server.port}');
  });
}
```
