// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library shelf_packages_handler;

import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:package_resolver/package_resolver.dart';
import 'package:path/path.dart' as p;

import 'src/async_handler.dart';
import 'src/dir_handler.dart';
import 'src/package_config_handler.dart';

/// A handler that serves the contents of a virtual packages directory.
///
/// This effectively serves `package:${request.url}`. It locates packages using
/// the package resolution logic defined by [resolver]. If [resolver] isn't
/// passed, it defaults to the current isolate's package resolution logic.
///
/// This can only serve assets from `file:` URIs.
Handler packagesHandler({PackageResolver resolver}) {
  resolver ??= PackageResolver.current;
  return new AsyncHandler(resolver.packageRoot.then((packageRoot) {
    if (packageRoot != null) {
      return createStaticHandler(p.fromUri(packageRoot),
          serveFilesOutsidePath: true);
    } else {
      return new PackageConfigHandler(resolver);
    }
  }));
}

/// A handler that serves virtual `packages/` directories wherever they're
/// requested.
///
/// This serves the same assets as [packagesHandler] for every URL that contains
/// `/packages/`. Otherwise, it returns 404s for all requests.
///
/// This is useful for ensuring that `package:` imports work for all entrypoints
/// in Dartium.
Handler packagesDirHandler({PackageResolver resolver}) =>
    new DirHandler("packages", packagesHandler(resolver: resolver));
