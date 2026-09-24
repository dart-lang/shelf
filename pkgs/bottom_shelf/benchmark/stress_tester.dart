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
  'Sec-Ch-Ua: "Not_A Brand";v="8", "Chromium";v="120", '
  '"Google Chrome";v="120"\r\n'
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
  const duration = Duration(seconds: 5);
  const concurrency = 50;

  print(
    'Benchmarking localhost:$port for ${duration.inSeconds}s with '
    '$concurrency concurrent connections...',
  );

  var totalRequests = 0;
  final stopwatch = Stopwatch()..start();

  final futures = <Future<void>>[];
  for (var i = 0; i < concurrency; i++) {
    futures.add(_runClient(port, duration, () => totalRequests++));
  }

  await Future.wait(futures);
  stopwatch.stop();

  final elapsedSeconds = stopwatch.elapsedMicroseconds / 1e6;
  final rps = totalRequests / elapsedSeconds;
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
  final buffer = <int>[];

  socket.listen(
    (data) {
      buffer.addAll(data);
      while (true) {
        final headerEnd = _findHeaderEnd(buffer);
        if (headerEnd == -1) break;
        final contentLength = _parseContentLength(buffer, headerEnd);
        final totalResponseBytes = headerEnd + 4 + contentLength;
        if (buffer.length < totalResponseBytes) break;

        buffer.removeRange(0, totalResponseBytes);
        onResponse();
        if (DateTime.now().isBefore(endTime)) {
          socket.add(request);
        } else {
          socket.destroy();
          if (!completer.isCompleted) completer.complete();
          return;
        }
      }
    },
    onDone: () {
      if (!completer.isCompleted) completer.complete();
    },
    onError: (Object e) {
      if (!completer.isCompleted) completer.complete();
    },
  );

  socket.add(request);
  return completer.future;
}

int _findHeaderEnd(List<int> bytes) {
  for (var i = 0; i <= bytes.length - 4; i++) {
    if (bytes[i] == 13 &&
        bytes[i + 1] == 10 &&
        bytes[i + 2] == 13 &&
        bytes[i + 3] == 10) {
      return i;
    }
  }
  return -1;
}

int _parseContentLength(List<int> bytes, int headerEnd) {
  final headers = ascii.decode(bytes.sublist(0, headerEnd));
  for (final line in headers.split('\r\n')) {
    if (line.toLowerCase().startsWith('content-length:')) {
      return int.tryParse(line.substring(15).trim()) ?? 0;
    }
  }
  return 0;
}
