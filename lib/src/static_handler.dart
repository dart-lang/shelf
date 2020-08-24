// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:convert/convert.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';

import 'directory_listing.dart';
import 'util.dart';

/// The default resolver for MIME types based on file extensions.
final _defaultMimeTypeResolver = MimeTypeResolver();

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
///
/// If [useHeaderBytesForContentType] is `true`, the contents of the
/// file will be used along with the file path to determine the content type.
///
/// Specify a custom [contentTypeResolver] to customize automatic content type
/// detection.
Handler createStaticHandler(String fileSystemPath,
    {bool serveFilesOutsidePath = false,
    String defaultDocument,
    bool listDirectories = false,
    bool useHeaderBytesForContentType = false,
    MimeTypeResolver contentTypeResolver}) {
  final rootDir = Directory(fileSystemPath);
  if (!rootDir.existsSync()) {
    throw ArgumentError('A directory corresponding to fileSystemPath '
        '"$fileSystemPath" could not be found');
  }

  fileSystemPath = rootDir.resolveSymbolicLinksSync();

  if (defaultDocument != null) {
    if (defaultDocument != p.basename(defaultDocument)) {
      throw ArgumentError('defaultDocument must be a file name.');
    }
  }

  contentTypeResolver ??= _defaultMimeTypeResolver;

  return (Request request) {
    final segs = [fileSystemPath, ...request.url.pathSegments];

    final fsPath = p.joinAll(segs);

    final entityType = FileSystemEntity.typeSync(fsPath, followLinks: true);

    File file;

    if (entityType == FileSystemEntityType.file) {
      file = File(fsPath);
    } else if (entityType == FileSystemEntityType.directory) {
      file = _tryDefaultFile(fsPath, defaultDocument);
      if (file == null && listDirectories) {
        final uri = request.requestedUri;
        if (!uri.path.endsWith('/')) return _redirectToAddTrailingSlash(uri);
        return listDirectory(fileSystemPath, fsPath);
      }
    }

    if (file == null) {
      return Response.notFound('Not Found');
    }

    if (!serveFilesOutsidePath) {
      final resolvedPath = file.resolveSymbolicLinksSync();

      // Do not serve a file outside of the original fileSystemPath
      if (!p.isWithin(fileSystemPath, resolvedPath)) {
        return Response.notFound('Not Found');
      }
    }

    // when serving the default document for a directory, if the requested
    // path doesn't end with '/', redirect to the path with a trailing '/'
    final uri = request.requestedUri;
    if (entityType == FileSystemEntityType.directory &&
        !uri.path.endsWith('/')) {
      return _redirectToAddTrailingSlash(uri);
    }

    return _handleFile(request, file, () async {
      if (useHeaderBytesForContentType) {
        final length = math.min(
            contentTypeResolver.magicNumbersMaxLength, file.lengthSync());

        final byteSink = ByteAccumulatorSink();

        await file.openRead(0, length).listen(byteSink.add).asFuture();

        return contentTypeResolver.lookup(file.path,
            headerBytes: byteSink.bytes);
      } else {
        return contentTypeResolver.lookup(file.path);
      }
    });
  };
}

Response _redirectToAddTrailingSlash(Uri uri) {
  final location = Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.port,
      path: '${uri.path}/',
      query: uri.query);

  return Response.movedPermanently(location.toString());
}

File _tryDefaultFile(String dirPath, String defaultFile) {
  if (defaultFile == null) return null;

  final filePath = p.join(dirPath, defaultFile);

  final file = File(filePath);

  if (file.existsSync()) {
    return file;
  }

  return null;
}

/// Creates a shelf [Handler] that serves the file at [path].
///
/// This returns a 404 response for any requests whose [Request.url] doesn't
/// match [url]. The [url] defaults to the basename of [path].
///
/// This uses the given [contentType] for the Content-Type header. It defaults
/// to looking up a content type based on [path]'s file extension, and failing
/// that doesn't sent a [contentType] header at all.
Handler createFileHandler(String path, {String url, String contentType}) {
  final file = File(path);
  if (!file.existsSync()) {
    throw ArgumentError.value(path, 'path', 'does not exist.');
  } else if (url != null && !p.url.isRelative(url)) {
    throw ArgumentError.value(url, 'url', 'must be relative.');
  }

  contentType ??= _defaultMimeTypeResolver.lookup(path);
  url ??= p.toUri(p.basename(path)).toString();

  return (request) {
    if (request.url.path != url) return Response.notFound('Not Found');
    return _handleFile(request, file, () => contentType);
  };
}

/// Serves the contents of [file] in response to [request].
///
/// This handles caching, and sends a 304 Not Modified response if the request
/// indicates that it has the latest version of a file. Otherwise, it calls
/// [getContentType] and uses it to populate the Content-Type header.
Future<Response> _handleFile(Request request, File file,
    FutureOr<String> Function() getContentType) async {
  final stat = file.statSync();
  final ifModifiedSince = request.ifModifiedSince;

  if (ifModifiedSince != null) {
    final fileChangeAtSecResolution = toSecondResolution(stat.modified);
    if (!fileChangeAtSecResolution.isAfter(ifModifiedSince)) {
      return Response.notModified();
    }
  }

  final headers = {
    HttpHeaders.contentLengthHeader: stat.size.toString(),
    HttpHeaders.lastModifiedHeader: formatHttpDate(stat.modified)
  };

  final contentType = await getContentType();
  if (contentType != null) headers[HttpHeaders.contentTypeHeader] = contentType;

  return Response.ok(file.openRead(), headers: headers);
}
