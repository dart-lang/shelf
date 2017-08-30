// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:package_resolver/package_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';

import 'async_handler.dart';

/// A shelf handler that serves a virtual packages directory based on a package
/// config.
class PackageConfigHandler {
  /// The static handlers for serving entries in the package config, indexed by
  /// name.
  final _packageHandlers = new Map<String, Handler>();

  /// The information specifying how to do package resolution.
  PackageResolver _resolver;

  PackageConfigHandler(this._resolver);

  /// The callback for handling a single request.
  FutureOr<Response> call(Request request) {
    var segments = request.url.pathSegments;
    return _handlerFor(segments.first)(request.change(path: segments.first));
  }

  /// Creates a handler for [package] based on the package map in [resolver].
  Handler _handlerFor(String package) {
    return _packageHandlers.putIfAbsent(package, () {
      return new AsyncHandler(_resolver.urlFor(package).then((url) {
        var handler = url == null
            ? (_) => new Response.notFound("Package $package not found.")
            : createStaticHandler(p.fromUri(url), serveFilesOutsidePath: true);

        return handler;
      }));
    });
  }
}
