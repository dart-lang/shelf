// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'message.dart';

final _emptyUint8List = Uint8List(0);

/// The body of a request or response.
///
/// This tracks whether the body has been read. It's separate from [Message]
/// because the message may be changed with [Message.change], but each instance
/// should share a notion of whether the body was read.
class Body {
  /// The streaming contents of the message body, if backed by a [Stream].
  Stream<List<int>>? _stream;

  /// The in-memory buffered bytes of the message body, if constructed from
  /// `null`, a [String], or a `List<int>`.
  List<int>? _bufferedBytes;

  /// Whether this body was constructed from `null`.
  final bool _isEmptyBody;

  /// Whether [read] or [takeBufferedBytes] has already been called.
  bool _isRead = false;

  /// Whether this body has already been consumed via [read] or
  /// [takeBufferedBytes].
  bool get isRead => _isRead;

  /// The encoding used to encode the stream returned by [read], or `null` if no
  /// encoding was used.
  final Encoding? encoding;

  /// The length of the stream returned by [read], or `null` if that can't be
  /// determined efficiently.
  final int? contentLength;

  Body._(
    this._stream,
    this._bufferedBytes,
    this.encoding,
    this.contentLength, {
    bool isEmptyBody = false,
  }) : _isEmptyBody = isEmptyBody;

  /// Converts [body] to a byte stream and wraps it in a [Body].
  ///
  /// [body] may be either a [Body], a [String], a `List<int>`, a
  /// `Stream<List<int>>`, or `null`. If it's a [String], [encoding] will be
  /// used to convert it to a `Stream<List<int>>`.
  factory Body(Object? body, [Encoding? encoding]) {
    if (body is Body) return body;

    if (body == null) {
      return Body._(null, _emptyUint8List, encoding, 0, isEmptyBody: true);
    } else if (body is String) {
      Uint8List encoded;
      if (encoding == null) {
        encoded = utf8.encode(body);
        // If the text is plain ASCII, don't modify the encoding. This means
        // that an encoding of "text/plain" will stay put.
        if (!_isPlainAscii(encoded, body.length)) encoding = utf8;
      } else {
        final list = encoding.encode(body);
        encoded = list is Uint8List ? list : Uint8List.fromList(list);
      }
      return Body._(null, encoded, encoding, encoded.length);
    } else if (body is List<int>) {
      // Preserve the exact List<int> instance for `read().single` while
      // avoiding allocating a Stream unless `read()` is actually called.
      return Body._(null, body, encoding, body.length);
    } else if (body is List) {
      final castList = body.cast<int>();
      return Body._(null, castList, encoding, body.length);
    } else if (body is Stream<List<int>>) {
      // Avoid performance overhead from an unnecessary cast.
      return Body._(body, null, encoding, null);
    } else if (body is Stream) {
      return Body._(body.cast(), null, encoding, null);
    } else {
      throw ArgumentError(
        'Response body "$body" must be a String or a '
        'Stream.',
      );
    }
  }

  /// Returns whether [bytes] is plain ASCII.
  ///
  /// [codeUnits] is the number of code units in the original string.
  static bool _isPlainAscii(List<int> bytes, int codeUnits) {
    // Most non-ASCII code units will produce multiple bytes and make the text
    // longer.
    if (bytes.length != codeUnits) return false;

    // Non-ASCII code units between U+0080 and U+009F produce 8-bit characters
    // with the high bit set.
    return bytes.every((byte) => byte & 0x80 == 0);
  }

  /// If this body is buffered in memory (`null`, [String], or `List<int>`),
  /// marks the body as read and returns the bytes as a [Uint8List] without
  /// allocating a [Stream].
  ///
  /// Returns `null` if this body is backed by a [Stream].
  /// Throws a [StateError] if the body has already been read.
  Uint8List? takeBufferedBytes() {
    if (_isRead) {
      throw StateError(
        "The 'read' method can only be called once on a "
        'shelf.Request/shelf.Response object.',
      );
    }
    final bytes = _bufferedBytes;
    if (bytes == null) return null;
    _isRead = true;
    _bufferedBytes = null;
    return bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  }

  /// Returns a [Stream] representing the body.
  ///
  /// Can only be called once.
  Stream<List<int>> read() {
    if (_isRead) {
      throw StateError(
        "The 'read' method can only be called once on a "
        'shelf.Request/shelf.Response object.',
      );
    }
    _isRead = true;
    if (_isEmptyBody) {
      _bufferedBytes = null;
      return const Stream<List<int>>.empty();
    }
    final bytes = _bufferedBytes;
    if (bytes != null) {
      _bufferedBytes = null;
      return Stream<List<int>>.value(bytes);
    }
    final stream = _stream!;
    _stream = null;
    return stream;
  }
}
