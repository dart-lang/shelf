// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';

/// A shelf handler that serves a virtual packages directory based on a package
/// config.
class PackageConfigHandler {
  /// The static handlers for serving entries in the package config, indexed by
  /// name.
  final _packageHandlers = <String, Handler>{};

  /// Optional, a map of package names to base uri for resolving `package:`
  /// uris for that package.
  final Map<String, Uri>? _packageMap;

  PackageConfigHandler({Map<String, Uri>? packageMap})
    : _packageMap = packageMap;

  /// The callback for handling a single request.
  Future<Response> handleRequest(Request request) async {
    final segments = request.url.pathSegments;
    if (segments.isEmpty) {
      return Response.notFound('Not found.');
    }

    final packageName = segments.first;
    if (!_isValidPackageName(packageName) ||
        !segments.skip(1).every(_isValidPathSegment)) {
      return Response.notFound('Not found.');
    }

    final handler = await _handlerFor(packageName);
    if (handler == null) {
      return Response.notFound('Package $packageName not found.');
    }
    return handler(request.change(path: packageName));
  }

  /// Creates a handler for [packageName] based on the package map in
  /// [_packageMap] or the current isolate resolver.
  Future<Handler?> _handlerFor(String packageName) async {
    final existing = _packageHandlers[packageName];
    if (existing != null) return existing;

    Uri? packageUri;
    if (_packageMap != null) {
      packageUri = _packageMap[packageName];
    } else {
      packageUri = await Isolate.resolvePackageUri(
        Uri(scheme: 'package', path: '$packageName/'),
      );
    }

    if (packageUri == null) return null;

    // `serveFilesOutsidePath: true` allows following symlinks inside package
    // directories (for example in Bazel runfiles or `build_runner`
    // symlink trees). Request path segments are validated above so requests
    // cannot lexically escape the package root.
    return _packageHandlers[packageName] ??= createStaticHandler(
      p.fromUri(packageUri),
      serveFilesOutsidePath: true,
    );
  }
}

// Reject `\` on all platforms since Dart package names never contain path
// separators, whereas `_isValidPathSegment` mirrors `package:path`'s
// platform-specific separator rules.
bool _isValidPackageName(String packageName) =>
    packageName.isNotEmpty &&
    packageName != '.' &&
    packageName != '..' &&
    !packageName.contains('/') &&
    !packageName.contains('\\') &&
    !packageName.contains('\x00');

bool _isValidPathSegment(String segment) {
  if (segment.isEmpty) return true;
  if (segment == '.' || segment == '..') return false;
  if (segment.contains('/') || segment.contains('\x00')) return false;
  if (p.style == p.Style.windows &&
      (segment.contains('\\') || segment.contains(':'))) {
    return false;
  }
  return true;
}
