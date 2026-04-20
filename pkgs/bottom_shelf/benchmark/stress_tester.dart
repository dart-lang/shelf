import 'dart:async';
import 'dart:convert';
import 'dart:io';

final request = utf8.encode(
  'GET / HTTP/1.1\r\n'
  'Host: localhost\r\n'
  'Connection: keep-alive\r\n'
  'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36\r\n'
  'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8\r\n'
  'Accept-Encoding: gzip, deflate, br\r\n'
  'Accept-Language: en-US,en;q=0.9\r\n'
  'Cache-Control: no-cache\r\n'
  'Pragma: no-cache\r\n'
  'Sec-Ch-Ua: "Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"\r\n'
  'Sec-Ch-Ua-Mobile: ?0\r\n'
  'Sec-Ch-Ua-Platform: "macOS"\r\n'
  'Sec-Fetch-Dest: document\r\n'
  'Sec-Fetch-Mode: navigate\r\n'
  'Sec-Fetch-Site: none\r\n'
  'Sec-Fetch-User: ?1\r\n'
  'Upgrade-Insecure-Requests: 1\r\n'
  '\r\n',
);

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart stress_tester.dart <port>');
    return;
  }
  final port = int.parse(args[0]);
  final duration = Duration(seconds: 5);
  final concurrency = 50;

  print(
    'Benchmarking localhost:$port for ${duration.inSeconds}s with $concurrency concurrent connections...',
  );

  var totalRequests = 0;
  final stopwatch = Stopwatch()..start();

  final futures = <Future>[];
  for (var i = 0; i < concurrency; i++) {
    futures.add(_runClient(port, duration, () => totalRequests++));
  }

  await Future.wait(futures);
  stopwatch.stop();

  final rps = totalRequests / stopwatch.elapsed.inSeconds;
  print('Total requests: $totalRequests');
  print('Requests per second: ${rps.toStringAsFixed(2)}');
}

Future<void> _runClient(
  int port,
  Duration duration,
  void Function() onResponse,
) async {
  final socket = await Socket.connect('localhost', port);
  final endTime = DateTime.now().add(duration);

  final completer = Completer<void>();

  socket.listen(
    (data) {
      onResponse();
      if (DateTime.now().isBefore(endTime)) {
        socket.add(request);
      } else {
        socket.destroy();
        if (!completer.isCompleted) completer.complete();
      }
    },
    onDone: () {
      if (!completer.isCompleted) completer.complete();
    },
    onError: (e) {
      if (!completer.isCompleted) completer.complete();
    },
  );

  socket.add(request);
  return completer.future;
}
