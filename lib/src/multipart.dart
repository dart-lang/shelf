// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:shelf/shelf.dart';

/// Extension methods to handle multipart requests.
///
/// To check whether a request contains multipart data, use [isMultipart].
/// Individual parts can the be red with [parts].
extension ReadMultipartRequest on Request {
  /// Whether this request has a multipart body.
  ///
  /// Requests are considered to have a multipart body if they have a
  /// `Content-Type` header with a `multipart` type and a valid `boundary`
  /// parameter as defined by section 5.1.1 of RFC 2046.
  bool get isMultipart => _extractMultipartBoundary() != null;

  /// Reads parts of this multipart request.
  ///
  /// Each part is represented as a [MimeMultipart], which implements the
  /// [Stream] interface to emit chunks of data.
  /// Headers of a part are available through [MimeMultipart.headers].
  ///
  /// Parts can be processed by listening to this stream, as shown in this
  /// example:
  ///
  /// ```dart
  /// await for (final part in request.parts) {
  ///   final headers = part.headers;
  ///   final content = utf8.decoder.bind(part).first;
  /// }
  /// ```
  ///
  /// Listening to this stream will [read] this request, which may only be done
  /// once.
  ///
  /// Throws a [StateError] if this is not a multipart request (as reported
  /// through [isMultipart]). The stream will emit a [MimeMultipartException]
  /// if the request does not contain a well-formed multipart body.
  Stream<MimeMultipart> get parts {
    final boundary = _extractMultipartBoundary();
    if (boundary == null) {
      throw StateError('Not a multipart request.');
    }

    return MimeMultipartTransformer(boundary)
        .bind(read())
        .map((part) => _CaseInsensitiveMultipart(part));
  }

  /// Extracts the `boundary` parameter from the content-type header, if this is
  /// a multipart request.
  String? _extractMultipartBoundary() {
    if (!headers.containsKey('Content-Type')) return null;

    final contentType = MediaType.parse(headers['Content-Type']!);
    if (contentType.type != 'multipart') return null;

    return contentType.parameters['boundary'];
  }
}

class _CaseInsensitiveMultipart extends MimeMultipart {
  final MimeMultipart _inner;

  @override
  final Map<String, String> headers;

  _CaseInsensitiveMultipart(this._inner)
      : headers = CaseInsensitiveMap.from(_inner.headers);

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> data)? onData,
      {void Function()? onDone, Function? onError, bool? cancelOnError}) {
    return _inner.listen(onData,
        onDone: onDone, onError: onError, cancelOnError: cancelOnError);
  }
}
