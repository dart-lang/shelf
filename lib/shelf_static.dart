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
  var rootDir = new Directory(fileSystemPath);
  fileSystemPath = rootDir.resolveSymbolicLinksSync();

  return (Request request) {

    var segs = [fileSystemPath]..addAll(request.requestedUri.pathSegments);

    var requestedPath = p.joinAll(segs);
    var file = new File(requestedPath);

    if (!file.existsSync()) {
      return new Response.notFound('Not Found');
    }

    var resolvedPath = file.resolveSymbolicLinksSync();

    // Do not serve a file outside of the original fileSystemPath
    if (!p.isWithin(fileSystemPath, resolvedPath)) {
      throw 'Requested path ${request.requestedUri} resolved to $resolvedPath '
          'is not under $fileSystemPath.';
    }

    var stats = file.statSync();

    var headers = <String, String>{
      HttpHeaders.CONTENT_LENGTH: stats.size.toString()
    };

    return new Response.ok(file.openRead(), headers: headers);
  };
}
