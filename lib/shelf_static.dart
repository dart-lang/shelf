library shelf_static;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';

// directory listing
// default document
// sym links
// mime type handling
// hidden files

Handler getHandler(String fileSystemPath) {
  return (Request request) {
    var rootDir = new Directory(fileSystemPath);
    var rootPath = rootDir.resolveSymbolicLinksSync();

    var segs = [rootPath]..addAll(request.pathSegments);

    var requestedPath = p.joinAll(segs);
    var file = new File(requestedPath);

    if (!file.existsSync()) {
      return new Response.notFound('Not Found');
    }

    var resolvedPath = file.resolveSymbolicLinksSync();

    // Do not serve a file outside of the original fileSystemPath
    if (!p.isWithin(rootPath, resolvedPath)) {
      throw 'Requested path ${request.pathInfo} resolved to $resolvedPath '
          'is not under $rootPath.';
    }

    var stats = file.statSync();

    var headers = {
      HttpHeaders.CONTENT_LENGTH: stats.size
    };

    return new Response.ok(file.openRead(), headers: headers);
  };
}
