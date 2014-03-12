library shelf_static;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';

// directory listing
// default document
// sym links
// mime type handling

Handler getHandler(String fileSystemPath) {
  return (Request request) {
    var rootDir = new Directory(fileSystemPath);
    var rootPath = rootDir.resolveSymbolicLinksSync();

    var segs = [rootPath]..addAll(request.pathSegments);

    var requestedPath = p.joinAll(segs);
    var file = new File(requestedPath);

    return file.resolveSymbolicLinks().then((String resolvedPath) {
      if(!p.isWithin(rootPath, resolvedPath)) {
        throw 'Requested path ${request.pathInfo} resolved to $resolvedPath is not under $rootPath.';
      }

      return new Response.ok(file.openRead());
    });
  };
}
