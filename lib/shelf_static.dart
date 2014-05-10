library shelf_static;

import 'dart:io';

import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart' as mime;
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';

// directory listing
// default document
// sym links
// hidden files

// TODO: {bool serveFilesOutsidePath}

/// Creates a Shelf [Handler] that serves files from the provided
/// [fileSystemPath].
Handler createStaticHandler(String fileSystemPath) {
  var rootDir = new Directory(fileSystemPath);
  if (!rootDir.existsSync()) {
    throw new ArgumentError('A directory corresponding to fileSystemPath '
        '"$fileSystemPath" could not be found');
  }

  fileSystemPath = rootDir.resolveSymbolicLinksSync();

  return (Request request) {
    // TODO: expand these checks and/or follow updates to Uri class to be more
    //       strict. https://code.google.com/p/dart/issues/detail?id=16081
    if (request.requestedUri.path.contains(' ')) {
      return new Response.forbidden('The requested path is invalid.');
    }

    var segs = [fileSystemPath]..addAll(request.url.pathSegments);

    var requestedPath = p.joinAll(segs);
    var file = new File(requestedPath);

    if (!file.existsSync()) {
      return new Response.notFound('Not Found');
    }

    var resolvedPath = file.resolveSymbolicLinksSync();

    // Do not serve a file outside of the original fileSystemPath
    if (!p.isWithin(fileSystemPath, resolvedPath)) {
      return new Response.notFound('Not Found');
    }

    var fileStat = file.statSync();

    var ifModifiedSince = request.ifModifiedSince;

    if (ifModifiedSince != null && !fileStat.changed.isAfter(ifModifiedSince)) {
      return new Response.notModified();
    }

    var headers = <String, String>{
      HttpHeaders.CONTENT_LENGTH: fileStat.size.toString(),
      HttpHeaders.LAST_MODIFIED: formatHttpDate(fileStat.changed)
    };

    var contentType = mime.lookupMimeType(requestedPath);

    if (contentType != null) {
      headers[HttpHeaders.CONTENT_TYPE] = contentType;
    }

    return new Response.ok(file.openRead(), headers: headers);
  };
}

/// Use [createStaticHandler] instead.
@deprecated
Handler getHandler(String fileSystemPath) =>
    createStaticHandler(fileSystemPath);
