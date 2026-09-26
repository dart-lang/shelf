// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

abstract final class $Chars {
  static const htab = 9;
  static const lf = 10;
  static const cr = 13;
  static const sp = 32;
  static const comma = 44;
  static const zero = 48;
  static const colon = 58;
  static const semicolon = 59;
}

abstract final class $Header {
  static const contentLength = 'content-length';
  static const contentType = 'content-type';
  static const ifModifiedSince = 'if-modified-since';
  static const host = 'host';
  static const connection = 'connection';
  static const transferEncoding = 'transfer-encoding';
  static const date = 'date';
}

abstract final class $Context {
  static const rawHeaders = 'shelf.raw.headers';
  static const connectionInfo = 'shelf.io.connection_info';
}

abstract final class $Limit {
  static const maxHeaderSize = 64 * 1024;
  static const maxFieldSize = 8 * 1024;
  static const maxUrlSize = 8 * 1024;
  static const maxContentLength = 32 * 1024 * 1024;

  /// Maximum body chunk size (16 KB) to coalesce into the header buffer.
  /// Payloads larger than this (e.g. 256 KB / 1 MB) are passed directly to
  /// `Socket.add` after `headerBytes` to avoid large buffer allocations and
  /// memory copies.
  static const maxCoalesceChunkSize = 16 * 1024;

  /// On keep-alive connections the socket is not flushed after every
  /// response (that would gate each pipelined request on the OS write
  /// draining). Instead we flush once at least 16 pipelined responses and
  /// this many unflushed bytes have accumulated.
  static const flushThreshold = 4 * 1024 * 1024;

  /// The maximum value of `_chunkSize` before shifting by 4 bits
  /// (multiplying by 16)
  /// to prevent overflow in a 64-bit signed integer.
  ///
  /// This corresponds to `0x7FFFFFFFFFFFFFFF >> 4`.
  static const maxChunkSizeBeforeShift = 0x07FFFFFFFFFFFFFF;
}
