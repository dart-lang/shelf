// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A Shelf adapter for handling [HttpRequest] objects from `dart:io`.
///
/// One can provide an instance of [HttpServer] as the `requests` parameter in
/// [serveRequests].
///
/// This adapter supports request hijacking; see [Request.hijack]. It also
/// supports the `"shelf.io.buffer_output"` `Response.context` property. If this
/// property is `true` (the default), streamed responses will be buffered to
/// improve performance; if it's `false`, all chunks will be pushed over the
/// wire as they're received. See [`HttpResponse.bufferOutput`][bufferOutput]
/// for more information.
///
/// `Request`s passed to a `Handler` will contain the
/// `"shelf.io.connection_info"` `Request.context` property, which holds the
/// `HttpConnectionInfo` object from the underlying `HttpRequest`.
///
/// [bufferOutput]: https://api.dartlang.org/apidocs/channels/stable/dartdoc-viewer/dart:io.HttpResponse#id_bufferOutput
import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:http_parser/http_parser.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:stream_channel/stream_channel.dart';

import 'shelf.dart';
import 'src/util.dart';

export 'src/io_server.dart';

/// Starts an [HttpServer] that listens on the specified [address] and
/// [port] and sends requests to [handler].
///
/// If a [securityContext] is provided an HTTPS server will be started.
////
/// See the documentation for [HttpServer.bind] and [HttpServer.bindSecure]
/// for more details on [address], [port], and [backlog].
Future<HttpServer> serve(Handler handler, address, int port,
    {SecurityContext securityContext, int backlog}) async {
  backlog ??= 0;
  HttpServer server = await (securityContext == null
      ? HttpServer.bind(address, port, backlog: backlog)
      : HttpServer.bindSecure(address, port, securityContext,
          backlog: backlog));
  serveRequests(server, handler);
  return server;
}

/// Serve a [Stream] of [HttpRequest]s.
///
/// [HttpServer] implements [Stream<HttpRequest>] so it can be passed directly
/// to [serveRequests].
///
/// Errors thrown by [handler] while serving a request will be printed to the
/// console and cause a 500 response with no body. Errors thrown asynchronously
/// by [handler] will be printed to the console or, if there's an active error
/// zone, passed to that zone.
void serveRequests(Stream<HttpRequest> requests, Handler handler) {
  catchTopLevelErrors(() {
    requests.listen((request) => handleRequest(request, handler));
  }, (error, stackTrace) {
    _logTopLevelError('Asynchronous error\n$error', stackTrace);
  });
}

/// Uses [handler] to handle [request].
///
/// Returns a [Future] which completes when the request has been handled.
Future handleRequest(HttpRequest request, Handler handler) async {
  var shelfRequest;
  try {
    shelfRequest = _fromHttpRequest(request);
  } catch (error, stackTrace) {
    var response =
        _logTopLevelError('Error parsing request.\n$error', stackTrace);
    await _writeResponse(response, request.response);
    return;
  }

  // TODO(nweiz): abstract out hijack handling to make it easier to implement an
  // adapter.
  var response;
  try {
    response = await handler(shelfRequest);
  } on HijackException catch (error, stackTrace) {
    // A HijackException should bypass the response-writing logic entirely.
    if (!shelfRequest.canHijack) return;

    // If the request wasn't hijacked, we shouldn't be seeing this exception.
    response = _logError(shelfRequest,
        "Caught HijackException, but the request wasn't hijacked.", stackTrace);
  } catch (error, stackTrace) {
    response =
        _logError(shelfRequest, 'Error thrown by handler.\n$error', stackTrace);
  }

  if (response == null) {
    await _writeResponse(_logError(shelfRequest, 'null response from handler.'),
        request.response);
    return;
  } else if (shelfRequest.canHijack) {
    await _writeResponse(response, request.response);
    return;
  }

  var message = new StringBuffer()
    ..writeln("Got a response for hijacked request "
        "${shelfRequest.method} ${shelfRequest.requestedUri}:")
    ..writeln(response.statusCode);
  response.headers.forEach((key, value) => message.writeln("$key: $value"));
  throw new Exception(message.toString().trim());
}

/// Creates a new [Request] from the provided [HttpRequest].
Request _fromHttpRequest(HttpRequest request) {
  var headers = <String, String>{};
  request.headers.forEach((k, v) {
    // Multiple header values are joined with commas.
    // See http://tools.ietf.org/html/draft-ietf-httpbis-p1-messaging-21#page-22
    headers[k] = v.join(',');
  });

  // Remove the Transfer-Encoding header per the adapter requirements.
  headers.remove(HttpHeaders.TRANSFER_ENCODING);

  void onHijack(void callback(StreamChannel<List<int>> channel)) {
    request.response
        .detachSocket(writeHeaders: false)
        .then((socket) => callback(new StreamChannel(socket, socket)));
  }

  return new Request(request.method, request.requestedUri,
      protocolVersion: request.protocolVersion,
      headers: headers,
      body: request,
      onHijack: onHijack,
      context: {'shelf.io.connection_info': request.connectionInfo});
}

Future _writeResponse(Response response, HttpResponse httpResponse) {
  if (response.context.containsKey("shelf.io.buffer_output")) {
    httpResponse.bufferOutput = response.context["shelf.io.buffer_output"];
  }

  httpResponse.statusCode = response.statusCode;

  // An adapter must not add or modify the `Transfer-Encoding` parameter, but
  // the Dart SDK sets it by default. Set this before we fill in
  // [response.headers] so that the user or Shelf can explicitly override it if
  // necessary.
  httpResponse.headers.chunkedTransferEncoding = false;

  response.headers.forEach((header, value) {
    if (value == null) return;
    httpResponse.headers.set(header, value);
  });

  var coding = response.headers['transfer-encoding'];
  if (coding != null && !equalsIgnoreAsciiCase(coding, 'identity')) {
    // If the response is already in a chunked encoding, de-chunk it because
    // otherwise `dart:io` will try to add another layer of chunking.
    //
    // TODO(nweiz): Do this more cleanly when sdk#27886 is fixed.
    response =
        response.change(body: chunkedCoding.decoder.bind(response.read()));
    httpResponse.headers.set(HttpHeaders.TRANSFER_ENCODING, 'chunked');
  } else if (response.statusCode >= 200 &&
      response.statusCode != 204 &&
      response.statusCode != 304 &&
      response.contentLength == null &&
      response.mimeType != 'multipart/byteranges') {
    // If the response isn't chunked yet and there's no other way to tell its
    // length, enable `dart:io`'s chunked encoding.
    httpResponse.headers.set(HttpHeaders.TRANSFER_ENCODING, 'chunked');
  }

  if (!response.headers.containsKey(HttpHeaders.SERVER)) {
    httpResponse.headers.set(HttpHeaders.SERVER, 'dart:io with Shelf');
  }

  if (!response.headers.containsKey(HttpHeaders.DATE)) {
    httpResponse.headers.date = new DateTime.now().toUtc();
  }

  return httpResponse
      .addStream(response.read())
      .then((_) => httpResponse.close());
}

// TODO(kevmoo) A developer mode is needed to include error info in response
// TODO(kevmoo) Make error output plugable. stderr, logging, etc
Response _logError(Request request, String message, [StackTrace stackTrace]) {
  // Add information about the request itself.
  var buffer = new StringBuffer();
  buffer.write("${request.method} ${request.requestedUri.path}");
  if (request.requestedUri.query.isNotEmpty) {
    buffer.write("?${request.requestedUri.query}");
  }
  buffer.writeln();
  buffer.write(message);

  return _logTopLevelError(buffer.toString(), stackTrace);
}

Response _logTopLevelError(String message, [StackTrace stackTrace]) {
  var chain = new Chain.current();
  if (stackTrace != null) {
    chain = new Chain.forTrace(stackTrace);
  }
  chain = chain
      .foldFrames((frame) => frame.isCore || frame.package == 'shelf')
      .terse;

  stderr.writeln('ERROR - ${new DateTime.now()}');
  stderr.writeln(message);
  stderr.writeln(chain);
  return new Response.internalServerError();
}
