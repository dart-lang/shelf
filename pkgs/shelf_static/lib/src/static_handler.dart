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
///
/// If [generateETag] is provided, it is used to generate an ETag for the
/// file. The ETag is then used to handle
/// [`If-None-Match`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/If-None-Match)
/// requests. If
/// [generateETag] is not provided, a default ETag is generated based on the
/// file's size and last modified time. To disable ETag generation, pass
/// `(file, stat) => null`.
///
/// If [maxAge] is provided, it is used to set the `Cache-Control` header
/// with a `max-age` value in seconds.
Handler createStaticHandler(String fileSystemPath,
    {bool serveFilesOutsidePath = false,
    String? defaultDocument,
    bool listDirectories = false,
    bool useHeaderBytesForContentType = false,
    MimeTypeResolver? contentTypeResolver,
    FutureOr<String?> Function(File, FileStat)? generateETag,
    Duration? maxAge}) {
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

  final mimeResolver = contentTypeResolver ?? _defaultMimeTypeResolver;

  return (Request request) async {
    final segs = [fileSystemPath, ...request.url.pathSegments];

    final fsPath = p.joinAll(segs);

    final stat = await FileStat.stat(fsPath);
    final entityType = stat.type;

    File? fileFound;
    FileStat? fileStat;

    if (entityType == FileSystemEntityType.file) {
      fileFound = File(fsPath);
      fileStat = stat;
    } else if (entityType == FileSystemEntityType.directory) {
      if (defaultDocument != null) {
        final defaultFilePath = p.join(fsPath, defaultDocument);
        final defaultFileStat = await FileStat.stat(defaultFilePath);
        if (defaultFileStat.type == FileSystemEntityType.file) {
          fileFound = File(defaultFilePath);
          fileStat = defaultFileStat;
        }
      }
      if (fileFound == null && listDirectories) {
        final uri = request.requestedUri;
        if (!uri.path.endsWith('/')) return _redirectToAddTrailingSlash(uri);
        return listDirectory(fileSystemPath, fsPath);
      }
    }

    if (fileFound == null) {
      return Response.notFound('Not Found');
    }
    final file = fileFound;

    if (!serveFilesOutsidePath) {
      final resolvedPath = await file.resolveSymbolicLinks();

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
        final length =
            math.min(mimeResolver.magicNumbersMaxLength, await file.length());

        final byteSink = ByteAccumulatorSink();

        await file.openRead(0, length).listen(byteSink.add).asFuture<void>();

        return mimeResolver.lookup(file.path, headerBytes: byteSink.bytes);
      } else {
        return mimeResolver.lookup(file.path);
      }
    }, generateETag: generateETag, maxAge: maxAge, fileStat: fileStat);
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

/// Creates a shelf [Handler] that serves the file at [path].
///
/// This returns a 404 response for any requests whose [Request.url] doesn't
/// match [url]. The [url] defaults to the basename of [path].
///
/// This uses the given [contentType] for the Content-Type header. It defaults
/// to looking up a content type based on [path]'s file extension, and failing
/// that doesn't sent a [contentType] header at all.
///
/// If [generateETag] is provided, it is used to generate an ETag for the
/// file. The ETag is then used to handle
/// [`If-None-Match`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/If-None-Match)
/// requests. If
/// [generateETag] is not provided, a default ETag is generated based on the
/// file's size and last modified time. To disable ETag generation, pass
/// `(file, stat) => null`.
///
/// If [maxAge] is provided, it is used to set the `Cache-Control` header
/// with a `max-age` value in seconds.
Handler createFileHandler(String path,
    {String? url,
    String? contentType,
    FutureOr<String?> Function(File, FileStat)? generateETag,
    Duration? maxAge}) {
  final file = File(path);
  if (!file.existsSync()) {
    throw ArgumentError.value(path, 'path', 'does not exist.');
  } else if (url != null && !p.url.isRelative(url)) {
    throw ArgumentError.value(url, 'url', 'must be relative.');
  }

  final mimeType = contentType ?? _defaultMimeTypeResolver.lookup(path);
  url ??= p.toUri(p.basename(path)).toString();

  return (request) async {
    if (request.url.path != url) return Response.notFound('Not Found');
    return _handleFile(request, file, () => mimeType,
        generateETag: generateETag, maxAge: maxAge);
  };
}

/// Serves the contents of [file] in response to [request].
///
/// This handles caching, and sends a 304 Not Modified response if the request
/// indicates that it has the latest version of a file. Otherwise, it calls
/// [getContentType] and uses it to populate the Content-Type header.
Future<Response> _handleFile(
    Request request, File file, FutureOr<String?> Function() getContentType,
    {FutureOr<String?> Function(File, FileStat)? generateETag,
    Duration? maxAge,
    FileStat? fileStat}) async {
  final stat = fileStat ?? await file.stat();
  final ifModifiedSince = request.ifModifiedSince;
  final ifNoneMatch = request.headers[HttpHeaders.ifNoneMatchHeader];

  generateETag ??= _defaultGenerateETag;
  final etag = await generateETag(file, stat);

  final cacheHeaders = {
    HttpHeaders.lastModifiedHeader: formatHttpDate(stat.modified),
    if (etag != null) HttpHeaders.etagHeader: etag,
    if (maxAge != null)
      HttpHeaders.cacheControlHeader: 'public, max-age=${maxAge.inSeconds}',
  };

  Response notModifiedResponse() => Response.notModified(headers: cacheHeaders);

  if (ifNoneMatch != null) {
    if (ifNoneMatch == '*') return notModifiedResponse();
    if (etag != null) {
      final clientETags = ifNoneMatch.split(',').map((e) => e.trim());
      if (clientETags.contains(etag)) {
        return notModifiedResponse();
      }
    }
  } else if (ifModifiedSince != null) {
    final fileChangeAtSecResolution = toSecondResolution(stat.modified);
    if (!fileChangeAtSecResolution.isAfter(ifModifiedSince)) {
      return notModifiedResponse();
    }
  }

  final contentType = await getContentType();
  final headers = {
    ...cacheHeaders,
    HttpHeaders.acceptRangesHeader: 'bytes',
    if (contentType != null) HttpHeaders.contentTypeHeader: contentType,
  };

  return _fileRangeResponse(request, file, stat.size, headers) ??
      Response.ok(
        request.method == 'HEAD' ? null : file.openRead(),
        headers: headers..[HttpHeaders.contentLengthHeader] = '${stat.size}',
      );
}

String _defaultGenerateETag(File file, FileStat stat) =>
    'W/"${stat.size}-${stat.modified.millisecondsSinceEpoch}"';

final _bytesMatcher = RegExp(r'^bytes=(\d*)-(\d*)$');

/// Serves a range of [file], if [request] is valid 'bytes' range request.
///
/// If the request does not specify a range, specifies a range of the wrong
/// type, or has a syntactic error the range is ignored and `null` is returned.
///
/// If the range request is valid but the file is not long enough to include the
/// start of the range a range not satisfiable response is returned.
///
/// Ranges that end past the end of the file are truncated.
Response? _fileRangeResponse(
    Request request, File file, int actualLength, Map<String, Object> headers) {
  final range = request.headers[HttpHeaders.rangeHeader];
  if (range == null) return null;
  final matches = _bytesMatcher.firstMatch(range);
  // Ignore ranges other than bytes
  if (matches == null) return null;

  final startMatch = matches[1]!;
  final endMatch = matches[2]!;
  if (startMatch.isEmpty && endMatch.isEmpty) return null;

  int start; // First byte position - inclusive.
  int end; // Last byte position - inclusive.
  if (startMatch.isEmpty) {
    start = actualLength - int.parse(endMatch);
    if (start < 0) start = 0;
    end = actualLength - 1;
  } else {
    start = int.parse(startMatch);
    end = endMatch.isEmpty ? actualLength - 1 : int.parse(endMatch);
  }

  // If the range is syntactically invalid the Range header
  // MUST be ignored (RFC 2616 section 14.35.1).
  if (start > end) return null;

  if (end >= actualLength) {
    end = actualLength - 1;
  }
  if (start >= actualLength) {
    return Response(
      HttpStatus.requestedRangeNotSatisfiable,
      headers: headers,
    );
  }
  return Response(
    HttpStatus.partialContent,
    body: request.method == 'HEAD' ? null : file.openRead(start, end + 1),
    headers: headers
      ..[HttpHeaders.contentLengthHeader] = (end - start + 1).toString()
      ..[HttpHeaders.contentRangeHeader] = 'bytes $start-$end/$actualLength',
  );
}
