// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:http_parser/http_parser.dart';
import 'package:stream_channel/stream_channel.dart';

import 'hijack_exception.dart';
import 'message.dart';
import 'util.dart';

/// A callback provided by a Shelf adapter that's used by [Request.hijack] to
/// provide a [HijackCallback] with a socket.
typedef void _OnHijackCallback(void callback(StreamChannel<List<int>> channel));

/// Represents an HTTP request to be processed by a Shelf application.
class Request extends Message {
  /// The URL path from the current handler to the requested resource, relative
  /// to [handlerPath], plus any query parameters.
  ///
  /// This should be used by handlers for determining which resource to serve,
  /// in preference to [requestedUri]. This allows handlers to do the right
  /// thing when they're mounted anywhere in the application. Routers should be
  /// sure to update this when dispatching to a nested handler, using the
  /// `path` parameter to [change].
  ///
  /// [url]'s path is always relative. It may be empty, if [requestedUri] ends
  /// at this handler. [url] will always have the same query parameters as
  /// [requestedUri].
  ///
  /// [handlerPath] and [url]'s path combine to create [requestedUri]'s path.
  final Uri url;

  /// The HTTP request method, such as "GET" or "POST".
  final String method;

  /// The URL path to the current handler.
  ///
  /// This allows a handler to know its location within the URL-space of an
  /// application. Routers should be sure to update this when dispatching to a
  /// nested handler, using the `path` parameter to [change].
  ///
  /// [handlerPath] is always a root-relative URL path; that is, it always
  /// starts with `/`. It will also end with `/` whenever [url]'s path is
  /// non-empty, or if [requestedUri]'s path ends with `/`.
  ///
  /// [handlerPath] and [url]'s path combine to create [requestedUri]'s path.
  final String handlerPath;

  /// The HTTP protocol version used in the request, either "1.0" or "1.1".
  final String protocolVersion;

  /// The original [Uri] for the request.
  final Uri requestedUri;

  /// The callback wrapper for hijacking this request.
  ///
  /// This will be `null` if this request can't be hijacked.
  final _OnHijack _onHijack;

  /// Whether this request can be hijacked.
  ///
  /// This will be `false` either if the adapter doesn't support hijacking, or
  /// if the request has already been hijacked.
  bool get canHijack => _onHijack != null && !_onHijack.called;

  /// If this is non-`null` and the requested resource hasn't been modified
  /// since this date and time, the server should return a 304 Not Modified
  /// response.
  ///
  /// This is parsed from the If-Modified-Since header in [headers]. If
  /// [headers] doesn't have an If-Modified-Since header, this will be `null`.
  DateTime get ifModifiedSince {
    if (_ifModifiedSinceCache != null) return _ifModifiedSinceCache;
    if (!headers.containsKey('if-modified-since')) return null;
    _ifModifiedSinceCache = parseHttpDate(headers['if-modified-since']);
    return _ifModifiedSinceCache;
  }

  DateTime _ifModifiedSinceCache;

  /// Creates a new [Request].
  ///
  /// [handlerPath] must be root-relative. [url]'s path must be fully relative,
  /// and it must have the same query parameters as [requestedUri].
  /// [handlerPath] and [url]'s path must combine to be the path component of
  /// [requestedUri]. If they're not passed, [handlerPath] will default to `/`
  /// and [url] to `requestedUri.path` without the initial `/`. If only one is
  /// passed, the other will be inferred.
  ///
  /// [body] is the request body. It may be either a [String], a [List<int>], a
  /// [Stream<List<int>>], or `null` to indicate no body. If it's a [String],
  /// [encoding] is used to encode it to a [Stream<List<int>>]. The default
  /// encoding is UTF-8.
  ///
  /// If [encoding] is passed, the "encoding" field of the Content-Type header
  /// in [headers] will be set appropriately. If there is no existing
  /// Content-Type header, it will be set to "application/octet-stream".
  ///
  /// The default value for [protocolVersion] is '1.1'.
  ///
  /// ## `onHijack`
  ///
  /// [onHijack] allows handlers to take control of the underlying socket for
  /// the request. It should be passed by adapters that can provide access to
  /// the bidirectional socket underlying the HTTP connection stream.
  ///
  /// The [onHijack] callback will only be called once per request. It will be
  /// passed another callback which takes a byte StreamChannel. [onHijack] must
  /// pass the channel for the connection stream to this callback, although it
  /// may do so asynchronously.
  ///
  /// If a request is hijacked, the adapter should expect to receive a
  /// [HijackException] from the handler. This is a special exception used to
  /// indicate that hijacking has occurred. The adapter should avoid either
  /// sending a response or notifying the user of an error if a
  /// [HijackException] is caught.
  ///
  /// An adapter can check whether a request was hijacked using [canHijack],
  /// which will be `false` for a hijacked request. The adapter may throw an
  /// error if a [HijackException] is received for a non-hijacked request, or if
  /// no [HijackException] is received for a hijacked request.
  ///
  /// See also [hijack].
  // TODO(kevmoo) finish documenting the rest of the arguments.
  Request(String method, Uri requestedUri,
      {String protocolVersion,
      Map<String, String> headers,
      String handlerPath,
      Uri url,
      body,
      Encoding encoding,
      Map<String, Object> context,
      void onHijack(void hijack(StreamChannel<List<int>> channel))})
      : this._(method, requestedUri,
            protocolVersion: protocolVersion,
            headers: headers,
            url: url,
            handlerPath: handlerPath,
            body: body,
            encoding: encoding,
            context: context,
            onHijack: onHijack == null ? null : new _OnHijack(onHijack));

  /// This constructor has the same signature as [new Request] except that
  /// accepts [onHijack] as [_OnHijack].
  ///
  /// Any [Request] created by calling [change] will pass [_onHijack] from the
  /// source [Request] to ensure that [hijack] can only be called once, even
  /// from a changed [Request].
  Request._(this.method, Uri requestedUri,
      {String protocolVersion,
      Map<String, String> headers,
      String handlerPath,
      Uri url,
      body,
      Encoding encoding,
      Map<String, Object> context,
      _OnHijack onHijack})
      : this.requestedUri = requestedUri,
        this.protocolVersion =
            protocolVersion == null ? '1.1' : protocolVersion,
        this.url = _computeUrl(requestedUri, handlerPath, url),
        this.handlerPath = _computeHandlerPath(requestedUri, handlerPath, url),
        this._onHijack = onHijack,
        super(body, encoding: encoding, headers: headers, context: context) {
    if (method.isEmpty) throw new ArgumentError('method cannot be empty.');

    if (!requestedUri.isAbsolute) {
      throw new ArgumentError(
          'requestedUri "$requestedUri" must be an absolute URL.');
    }

    if (requestedUri.fragment.isNotEmpty) {
      throw new ArgumentError(
          'requestedUri "$requestedUri" may not have a fragment.');
    }

    if (this.handlerPath + this.url.path != this.requestedUri.path) {
      throw new ArgumentError('handlerPath "$handlerPath" and url "$url" must '
          'combine to equal requestedUri path "${requestedUri.path}".');
    }
  }

  /// Creates a new [Request] by copying existing values and applying specified
  /// changes.
  ///
  /// New key-value pairs in [context] and [headers] will be added to the copied
  /// [Request]. If [context] or [headers] includes a key that already exists,
  /// the key-value pair will replace the corresponding entry in the copied
  /// [Request]. All other context and header values from the [Request] will be
  /// included in the copied [Request] unchanged.
  ///
  /// [body] is the request body. It may be either a [String], a [List<int>], a
  /// [Stream<List<int>>], or `null` to indicate no body.
  ///
  /// [path] is used to update both [handlerPath] and [url]. It's designed for
  /// routing middleware, and represents the path from the current handler to
  /// the next handler. It must be a prefix of [url]; [handlerPath] becomes
  /// `handlerPath + "/" + path`, and [url] becomes relative to that. For
  /// example:
  ///
  ///     print(request.handlerPath); // => /static/
  ///     print(request.url);        // => dir/file.html
  ///
  ///     request = request.change(path: "dir");
  ///     print(request.handlerPath); // => /static/dir/
  ///     print(request.url);        // => file.html
  Request change(
      {Map<String, String> headers,
      Map<String, Object> context,
      String path,
      body}) {
    headers = updateMap(this.headers, headers);
    context = updateMap(this.context, context);

    if (body == null) body = getBody(this);

    var handlerPath = this.handlerPath;
    if (path != null) handlerPath += path;

    return new Request._(this.method, this.requestedUri,
        protocolVersion: this.protocolVersion,
        headers: headers,
        handlerPath: handlerPath,
        body: body,
        context: context,
        onHijack: _onHijack);
  }

  /// Takes control of the underlying request socket.
  ///
  /// Synchronously, this throws a [HijackException] that indicates to the
  /// adapter that it shouldn't emit a response itself. Asynchronously,
  /// [callback] is called with a [StreamChannel<List<int>>] that provides
  /// access to the underlying request socket.
  ///
  /// This may only be called when using a Shelf adapter that supports
  /// hijacking, such as the `dart:io` adapter. In addition, a given request may
  /// only be hijacked once. [canHijack] can be used to detect whether this
  /// request can be hijacked.
  void hijack(void callback(StreamChannel<List<int>> channel)) {
    if (_onHijack == null) {
      throw new StateError("This request can't be hijacked.");
    }

    _onHijack.run(callback);

    throw const HijackException();
  }
}

/// A class containing a callback for [Request.hijack] that also tracks whether
/// the callback has been called.
class _OnHijack {
  /// The callback.
  final _OnHijackCallback _callback;

  /// Whether [this] has been called.
  bool called = false;

  _OnHijack(this._callback);

  /// Calls [this].
  ///
  /// Throws a [StateError] if [this] has already been called.
  void run(void callback(StreamChannel<List<int>> channel)) {
    if (called) throw new StateError("This request has already been hijacked.");
    called = true;
    newFuture(() => _callback(callback));
  }
}

/// Computes `url` from the provided [Request] constructor arguments.
///
/// If [url] is `null`, the value is inferred from [requestedUri] and
/// [handlerPath] if available. Otherwise [url] is returned.
Uri _computeUrl(Uri requestedUri, String handlerPath, Uri url) {
  if (handlerPath != null &&
      handlerPath != requestedUri.path &&
      !handlerPath.endsWith("/")) {
    handlerPath += "/";
  }

  if (url != null) {
    if (url.scheme.isNotEmpty || url.hasAuthority || url.fragment.isNotEmpty) {
      throw new ArgumentError('url "$url" may contain only a path and query '
          'parameters.');
    }

    if (!requestedUri.path.endsWith(url.path)) {
      throw new ArgumentError('url "$url" must be a suffix of requestedUri '
          '"$requestedUri".');
    }

    if (requestedUri.query != url.query) {
      throw new ArgumentError('url "$url" must have the same query parameters '
          'as requestedUri "$requestedUri".');
    }

    if (url.path.startsWith('/')) {
      throw new ArgumentError('url "$url" must be relative.');
    }

    var startOfUrl = requestedUri.path.length - url.path.length;
    if (url.path.isNotEmpty &&
        requestedUri.path.substring(startOfUrl - 1, startOfUrl) != '/') {
      throw new ArgumentError('url "$url" must be on a path boundary in '
          'requestedUri "$requestedUri".');
    }

    return url;
  } else if (handlerPath != null) {
    return new Uri(
        path: requestedUri.path.substring(handlerPath.length),
        query: requestedUri.query);
  } else {
    // Skip the initial "/".
    var path = requestedUri.path.substring(1);
    return new Uri(path: path, query: requestedUri.query);
  }
}

/// Computes `handlerPath` from the provided [Request] constructor arguments.
///
/// If [handlerPath] is `null`, the value is inferred from [requestedUri] and
/// [url] if available. Otherwise [handlerPath] is returned.
String _computeHandlerPath(Uri requestedUri, String handlerPath, Uri url) {
  if (handlerPath != null &&
      handlerPath != requestedUri.path &&
      !handlerPath.endsWith("/")) {
    handlerPath += "/";
  }

  if (handlerPath != null) {
    if (!requestedUri.path.startsWith(handlerPath)) {
      throw new ArgumentError('handlerPath "$handlerPath" must be a prefix of '
          'requestedUri path "${requestedUri.path}"');
    }

    if (!handlerPath.startsWith('/')) {
      throw new ArgumentError(
          'handlerPath "$handlerPath" must be root-relative.');
    }

    return handlerPath;
  } else if (url != null) {
    if (url.path.isEmpty) return requestedUri.path;

    var index = requestedUri.path.indexOf(url.path);
    return requestedUri.path.substring(0, index);
  } else {
    return '/';
  }
}
