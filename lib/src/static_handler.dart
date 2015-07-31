// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library shelf_static.static_handler;

import 'dart:io';

import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart' as mime;
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';

import 'directory_listing.dart';
import 'util.dart';

// TODO option to exclude hidden files?

/// Creates a Shelf [Handler] that serves files from the provided
/// [fileSystemPath].
///
/// Accessing a path containing symbolic links will succeed only if the resolved
/// path is within [fileSystemPath]. To allow access to paths outside of
/// [fileSystemPath], set [serveFilesOutsidePath] to `true`.
///
/// When a existing directory is requested and a [defaultDocument] is specified
/// the directory is checked for a file with that name. If it exists, it is
/// served.
///
/// If no [defaultDocument] is found and [listDirectories] is true, then the
/// handler produces a listing of the directory.
Handler createStaticHandler(String fileSystemPath,
    {bool serveFilesOutsidePath: false, String defaultDocument,
    bool listDirectories: false}) {
  var rootDir = new Directory(fileSystemPath);
  if (!rootDir.existsSync()) {
    throw new ArgumentError('A directory corresponding to fileSystemPath '
        '"$fileSystemPath" could not be found');
  }

  fileSystemPath = rootDir.resolveSymbolicLinksSync();

  if (defaultDocument != null) {
    if (defaultDocument != p.basename(defaultDocument)) {
      throw new ArgumentError('defaultDocument must be a file name.');
    }
  }

  return (Request request) {
    var segs = [fileSystemPath]..addAll(request.url.pathSegments);

    var fsPath = p.joinAll(segs);

    var entityType = FileSystemEntity.typeSync(fsPath, followLinks: true);

    File file = null;

    if (entityType == FileSystemEntityType.FILE) {
      file = new File(fsPath);
    } else if (entityType == FileSystemEntityType.DIRECTORY) {
      file = _tryDefaultFile(fsPath, defaultDocument);
      if (file == null && listDirectories) {
        var uri = request.requestedUri;
        if (!uri.path.endsWith('/')) return _redirectToAddTrailingSlash(uri);
        return listDirectory(fileSystemPath, fsPath);
      }
    }

    if (file == null) {
      return new Response.notFound('Not Found');
    }

    if (!serveFilesOutsidePath) {
      var resolvedPath = file.resolveSymbolicLinksSync();

      // Do not serve a file outside of the original fileSystemPath
      if (!p.isWithin(fileSystemPath, resolvedPath)) {
        return new Response.notFound('Not Found');
      }
    }

    // when serving the default document for a directory, if the requested
    // path doesn't end with '/', redirect to the path with a trailing '/'
    var uri = request.requestedUri;
    if (entityType == FileSystemEntityType.DIRECTORY &&
        !uri.path.endsWith('/')) {
      return _redirectToAddTrailingSlash(uri);
    }

    var fileStat = file.statSync();
    var ifModifiedSince = request.ifModifiedSince;

    if (ifModifiedSince != null) {
      var fileChangeAtSecResolution = toSecondResolution(fileStat.changed);
      if (!fileChangeAtSecResolution.isAfter(ifModifiedSince)) {
        return new Response.notModified();
      }
    }

    var headers = <String, String>{
      HttpHeaders.CONTENT_LENGTH: fileStat.size.toString(),
      HttpHeaders.LAST_MODIFIED: formatHttpDate(fileStat.changed)
    };

    var contentType = mime.lookupMimeType(file.path);
    if (contentType != null) {
      headers[HttpHeaders.CONTENT_TYPE] = contentType;
    }

    return new Response.ok(file.openRead(), headers: headers);
  };
}

Response _redirectToAddTrailingSlash(Uri uri) {
  var location = new Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.port,
      path: uri.path + '/',
      query: uri.query);

  return new Response.movedPermanently(location.toString());
}

File _tryDefaultFile(String dirPath, String defaultFile) {
  if (defaultFile == null) return null;

  var filePath = p.join(dirPath, defaultFile);

  var file = new File(filePath);

  if (file.existsSync()) {
    return file;
  }

  return null;
}
