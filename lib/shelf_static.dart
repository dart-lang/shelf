library shelf_static;

import 'dart:io';

import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart' as mime;
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';

import 'src/util.dart';

// directory listing
// hidden files

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
Handler createStaticHandler(String fileSystemPath,
    {bool serveFilesOutsidePath: false, String defaultDocument}) {
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
    // TODO: expand these checks and/or follow updates to Uri class to be more
    //       strict. https://code.google.com/p/dart/issues/detail?id=16081
    if (request.requestedUri.path.contains(' ')) {
      return new Response.forbidden('The requested path is invalid.');
    }

    var segs = [fileSystemPath]..addAll(request.url.pathSegments);

    var requestedPath = p.joinAll(segs);

    var fileType = FileSystemEntity.typeSync(requestedPath, followLinks: true);

    File file = null;

    if (fileType == FileSystemEntityType.FILE) {
      file = new File(requestedPath);
    } else if (fileType == FileSystemEntityType.DIRECTORY) {
      file = _tryDefaultFile(requestedPath, defaultDocument);
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

    if (fileType == FileSystemEntityType.DIRECTORY &&
        !request.url.path.endsWith('/')) {
      // when serving the default document for a directory, if the requested
      // path doesn't end with '/', redirect to the path with a trailing '/'
      var uri = request.requestedUri;
      assert(!uri.path.endsWith('/'));
      var location = new Uri(scheme: uri.scheme, userInfo: uri.userInfo,
          host: uri.host, port: uri.port, path: uri.path + '/',
          query: uri.query);

      return new Response.movedPermanently(location.toString());
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

    var contentType = mime.lookupMimeType(requestedPath);

    if (contentType != null) {
      headers[HttpHeaders.CONTENT_TYPE] = contentType;
    }

    return new Response.ok(file.openRead(), headers: headers);
  };
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

/// Use [createStaticHandler] instead.
@deprecated
Handler getHandler(String fileSystemPath) =>
    createStaticHandler(fileSystemPath);
