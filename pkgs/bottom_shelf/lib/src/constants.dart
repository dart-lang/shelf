// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

abstract final class $Chars {
  static const lf = 10;
  static const cr = 13;
  static const sp = 32;
  static const zero = 48;
  static const colon = 58;
  static const semicolon = 59;
}

abstract final class $Header {
  static const contentLength = 'content-length';
  static const contentType = 'content-type';
  static const ifModifiedSince = 'if-modified-since';
  static const host = 'host';
  static const connection = 'connection';
  static const transferEncoding = 'transfer-encoding';
}
