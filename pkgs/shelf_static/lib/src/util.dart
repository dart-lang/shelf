// Copyright (c) 2015, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Truncates [dt] to the resolution an HTTP date can express: whole seconds.
///
/// A file's modification time can carry sub-millisecond precision, which
/// `Last-Modified` cannot represent. Dropping only the milliseconds leaves the
/// microseconds behind, so the truncated time stays *after* the date that was
/// published and every conditional request is answered with a full `200`.
DateTime toSecondResolution(DateTime dt) => dt.subtract(
      Duration(milliseconds: dt.millisecond, microseconds: dt.microsecond),
    );
