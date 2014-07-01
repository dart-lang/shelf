library shelf_proxy.harness_console;

import 'package:scheduled_test/scheduled_test.dart';

import 'proxy_test.dart' as proxy;
import 'static_file_test.dart' as static_file;

void main() {
  groupSep = ' - ';

  group('proxy', proxy.main);
  group('static file example', static_file.main);
}
