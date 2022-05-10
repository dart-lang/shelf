import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';

void main(List<String> arguments) {
  final app = Router();
  
  app.get(
      '/ws',
      (Request request, [__]) => webSocketHandler((webSocket) {
            webSocket.stream.listen((message) {
              webSocket.sink.add("echo $message");
            });
          })(request));
          
  io
      .serve(app, 'localhost', 3000)
      .then((server) => print(`Server listen on ${server.address.host} ${server.port}`));  
}
