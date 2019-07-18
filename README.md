## Proxy for Shelf

[![Build Status](https://travis-ci.org/dart-lang/shelf_proxy.svg?branch=master)](https://travis-ci.org/dart-lang/shelf_proxy)

`shelf_proxy` is a [Shelf][] handler that proxies requests to an external
server. It can be served directly and used as a proxy server, or it can be
mounted within a larger application to proxy only certain URLs.

[Shelf]: https://pub.dev/packages/shelf

```dart
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_proxy/shelf_proxy.dart';

void main() async {
  var server = await shelf_io.serve(
    proxyHandler("https://dart.dev"),
    'localhost',
    8080,
  );

  print('Proxying at http://${server.address.host}:${server.port}');
}
```
