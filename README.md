## Web Socket Handler for Shelf

`shelf_web_socket` is a [Shelf][] handler for establishing [WebSocket][]
connections. It exposes a single function, [webSocketHandler][], which calls an
`onConnection` callback with a [CompatibleWebSocket][] object for every
connection that's established.

[Shelf]: https://pub.dartlang.org/packages/shelf

[WebSocket]: https://tools.ietf.org/html/rfc6455

[webSocketHandler]: https://pub.dartlang.org/documentation/shelf_web_socket/latest/shelf_web_socket/webSocketHandler.html

[CompatibleWebSocket]: https://api.dartlang.org/apidocs/channels/be/dartdoc-viewer/http_parser/http_parser.CompatibleWebSocket

```dart
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';

void main() {
  var handler = webSocketHandler((webSocket) {
    webSocket.stream.listen((message) {
      webSocket.sink.add("echo $message");
    });
  });

  shelf_io.serve(handler, 'localhost', 8080).then((server) {
    print('Serving at ws://${server.address.host}:${server.port}');
  });
}
```
