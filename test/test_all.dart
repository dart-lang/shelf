// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library shelf_static.test_all;

import 'package:scheduled_test/scheduled_test.dart';

import 'alternative_root_test.dart' as alternative_root;
import 'basic_file_test.dart' as basic_file;
import 'default_document_test.dart' as default_document;
import 'get_handler_test.dart' as get_handler;
import 'sample_test.dart' as sample;
import 'symbolic_link_test.dart' as symbolic_link;

void main() {
  group('alternative_root', alternative_root.main);
  group('basic_file', basic_file.main);
  group('default_document', default_document.main);
  group('get_handler', get_handler.main);
  group('sample', sample.main);
  group('symbolic_link', symbolic_link.main);
}
