// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

DateTime toSecondResolution(DateTime dt) {
  if (dt.millisecond == 0) return dt;
  return dt.subtract(Duration(milliseconds: dt.millisecond));
}

Map<String, Object>? buildResponseContext(
    {File? file, File? fileNotFound, Directory? directory}) {
  // Ensure other shelf `Middleware` can identify
  // the processed file/directory in the `Response` by including
  // `file`, `file_not_found` and `directory` in the context:
  if (file != null) {
    return {'shelf_static:file': file};
  } else if (fileNotFound != null) {
    return {'shelf_static:file_not_found': fileNotFound};
  } else if (directory != null) {
    return {'shelf_static:directory': directory};
  } else {
    return null;
  }
}
