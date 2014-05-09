library shelf_static.harness_console;

import 'package:scheduled_test/scheduled_test.dart';

import 'alternative_root_test.dart' as alternative_root;
import 'basic_file_test.dart' as basic_file;
import 'sample_test.dart' as sample;

void main() {
  groupSep = ' - ';
  group('alternative_root', alternative_root.main);
  group('basic_file', basic_file.main);
  group('sample', sample.main);
}
