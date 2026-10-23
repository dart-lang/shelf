// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Conformance tests for shelf server adapters, such as `shelf_io`.
///
/// Call `testAll` from an adapter's tests.
library;

export 'src/adapter/adapter_tests.dart' show testAll;
export 'src/adapter/conformance_server.dart'
    show ConformanceServer, ServeCallback, ServeOptions;
