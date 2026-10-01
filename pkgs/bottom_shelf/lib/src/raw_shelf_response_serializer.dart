// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:shelf/shelf.dart';
import 'constants.dart';
import 'utils.dart';

/// Serializes a [Response] directly to a [Socket].
final class RawShelfResponseSerializer {
  static final Uint8List _crlf = Uint8List.fromList([$Chars.cr, $Chars.lf]);
  static final Uint8List _chunkedEnd = Uint8List.fromList([
    $Chars.zero,
    $Chars.cr,
    $Chars.lf,
    $Chars.cr,
    $Chars.lf,
  ]);
  static final Uint8List _crlfChunkedEnd = Uint8List.fromList([
    $Chars.cr,
    $Chars.lf,
    $Chars.zero,
    $Chars.cr,
    $Chars.lf,
    $Chars.cr,
    $Chars.lf,
  ]);

  static final Uint8List _connectionKeepAlive = ascii.encode(
    'Connection: keep-alive\r\n',
  );
  static final Uint8List _connectionClose = ascii.encode(
    'Connection: close\r\n',
  );
  static final Uint8List _transferEncodingChunked = ascii.encode(
    'Transfer-Encoding: chunked\r\n',
  );

  static final _statusLineCache = <int, Uint8List>{};
  static Uint8List _statusLine(int code) => _statusLineCache[code] ??= ascii
      .encode('HTTP/1.1 $code ${_getStatusPhrase(code)}\r\n');

  static int _cachedSecond = 0;
  static Uint8List _cachedDateBytes = Uint8List(0);

  static Uint8List _dateHeaderBytes() {
    final now = DateTime.now();
    final second = now.millisecondsSinceEpoch ~/ 1000;
    if (second != _cachedSecond) {
      _cachedSecond = second;
      _cachedDateBytes = ascii.encode('Date: ${HttpDate.format(now)}\r\n');
    }
    return _cachedDateBytes;
  }

  /// Scratch buffer for building header bytes. Safe to reuse: header
  /// serialization is fully synchronous (no `await` while it is live) and
  /// the isolate is single-threaded.
  static Uint8List _scratch = Uint8List(4096);
  static int _scratchPos = 0;

  static void _ensure(int n) {
    if (_scratchPos + n > _scratch.length) {
      final grown = Uint8List(math.max(_scratch.length * 2, _scratchPos + n));
      grown.setRange(0, _scratchPos, _scratch);
      _scratch = grown;
    }
  }

  static void _addBytes(Uint8List bytes) {
    _ensure(bytes.length);
    _scratch.setRange(_scratchPos, _scratchPos + bytes.length, bytes);
    _scratchPos += bytes.length;
  }

  /// Writes a trusted internal ASCII literal (no validation).
  static void _addString(String s) {
    _ensure(s.length);
    for (var i = 0; i < s.length; i++) {
      _scratch[_scratchPos++] = s.codeUnitAt(i);
    }
  }

  /// Writes a header name, enforcing RFC 9110 token characters. Rejecting
  /// CR/LF/colon/etc. here prevents response splitting via handler-supplied
  /// header names.
  static void _addHeaderName(String s) {
    _ensure(s.length);
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (c > 0xFF || !isTchar(c)) {
        throw ArgumentError.value(
          s,
          'header',
          'Invalid character in response header name',
        );
      }
      _scratch[_scratchPos++] = c;
    }
  }

  /// Writes a header value as Latin-1, rejecting NUL/CR/LF and code units
  /// above 0xFF. Rejecting CR/LF here prevents response splitting via
  /// handler-supplied header values.
  static void _addHeaderValue(String s) {
    _ensure(s.length);
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (c == 0x00 || c == 0x0A || c == 0x0D || c > 0xFF) {
        throw ArgumentError.value(
          s,
          'header',
          'Invalid character in response header value',
        );
      }
      _scratch[_scratchPos++] = c;
    }
  }

  static void _addCrlf() {
    _ensure(2);
    _scratch[_scratchPos++] = $Chars.cr;
    _scratch[_scratchPos++] = $Chars.lf;
  }

  static bool _equalsIgnoreAsciiCase(String key, String lower) {
    if (key.length != lower.length) return false;
    for (var i = 0; i < key.length; i++) {
      var c = key.codeUnitAt(i);
      if (c >= 0x41 && c <= 0x5A) c += 0x20;
      if (c != lower.codeUnitAt(i)) return false;
    }
    return true;
  }

  /// Serializes [response] to [socket] and returns the number of bytes
  /// written. Does NOT flush — the caller decides when to flush (see
  /// `$Limit.flushThreshold`).
  static FutureOr<int> writeResponse(
    Response response,
    Socket socket, {
    required bool keepAlive,
    required String requestMethod,
    String? poweredBy,
    void Function()? onHeadersSent,
  }) {
    final statusCode = response.statusCode;
    final isBodylessStatus =
        (statusCode >= 100 && statusCode < 200) ||
        statusCode == 204 ||
        statusCode == 304;

    _scratchPos = 0;
    _addBytes(_statusLine(statusCode));
    final (:contentLength, :isChunked) = _addHeaders(
      response,
      isBodylessStatus: isBodylessStatus,
      keepAlive: keepAlive,
      poweredBy: poweredBy,
    );
    _addCrlf();

    final bufferedBytes = response.runtimeType == Response
        ? extractBody(response).takeBufferedBytes()
        : null;

    if (bufferedBytes != null) {
      return _writeBufferedBody(
        socket,
        bufferedBytes,
        requestMethod: requestMethod,
        contentLength: contentLength,
        isBodylessStatus: isBodylessStatus,
        isChunked: isChunked,
        onHeadersSent: onHeadersSent,
      );
    }

    // Materialize before any await: the static scratch buffer is shared
    // across all connections in this isolate and interleaving writeResponse
    // calls resume at await boundaries.
    final headerBytes = _takeScratch();

    return _writeStreamResponse(
      response,
      socket,
      headerBytes: headerBytes,
      requestMethod: requestMethod,
      contentLength: contentLength,
      isBodylessStatus: isBodylessStatus,
      isChunked: isChunked,
      onHeadersSent: onHeadersSent,
    );
  }

  /// Appends the response headers to the scratch buffer, adding the framing
  /// headers the handler did not set.
  ///
  /// Returns the declared `Content-Length` (`null` when absent or unparsable)
  /// and whether the body will be sent chunked.
  static ({int? contentLength, bool isChunked}) _addHeaders(
    Response response, {
    required bool isBodylessStatus,
    required bool keepAlive,
    required String? poweredBy,
  }) {
    final statusCode = response.statusCode;
    final forbidContentLength =
        (statusCode >= 100 && statusCode < 200) || statusCode == 204;

    var hasContentLength = false;
    var hasTransferEncoding = false;
    var hasConnection = false;
    var hasDate = false;
    var hasPoweredBy = false;
    int? contentLength;

    response.headersAll.forEach((key, values) {
      if (values.isEmpty) return;
      switch (key.length) {
        case 14 when _equalsIgnoreAsciiCase(key, 'content-length'):
          if (forbidContentLength) return;
          hasContentLength = true;
          contentLength = int.tryParse(values.first);
        case 17 when _equalsIgnoreAsciiCase(key, 'transfer-encoding'):
          if (isBodylessStatus) return;
          hasTransferEncoding = true;
        case 10 when _equalsIgnoreAsciiCase(key, 'connection'):
          hasConnection = true;
        case 10 when _equalsIgnoreAsciiCase(key, 'set-cookie'):
          _addSetCookieHeaders(key, values);
          return;
        case 4 when _equalsIgnoreAsciiCase(key, 'date'):
          hasDate = true;
        case 12 when _equalsIgnoreAsciiCase(key, 'x-powered-by'):
          hasPoweredBy = true;
      }
      _addHeader(key, values);
    });

    // `Message.contentLength` derives from the `content-length` header, so
    // when the header is absent (and the status allows a body) the body length
    // is unknown: chunk it.
    final isChunked = !hasContentLength && !isBodylessStatus;

    if (isChunked && !hasTransferEncoding) {
      _addBytes(_transferEncodingChunked);
    }
    if (!hasConnection) {
      _addBytes(keepAlive ? _connectionKeepAlive : _connectionClose);
    }
    if (poweredBy != null && !hasPoweredBy) {
      _addString('X-Powered-By: ');
      _addHeaderValue(poweredBy);
      _addCrlf();
    }
    if (!hasDate) {
      _addBytes(_dateHeaderBytes());
    }
    return (contentLength: contentLength, isChunked: isChunked);
  }

  static void _addColonSpace() {
    _ensure(2);
    _scratch[_scratchPos++] = $Chars.colon;
    _scratch[_scratchPos++] = $Chars.sp;
  }

  /// `key: v1, v2\r\n`
  static void _addHeader(String key, List<String> values) {
    _addHeaderName(key);
    _addColonSpace();
    for (var i = 0; i < values.length; i++) {
      if (i > 0) _addString(', ');
      _addHeaderValue(values[i]);
    }
    _addCrlf();
  }

  /// `Set-Cookie` must not be comma-joined: one line per value. The name is
  /// validated once and written as a trusted literal after that.
  static void _addSetCookieHeaders(String key, List<String> values) {
    for (var i = 0; i < values.length; i++) {
      if (i == 0) {
        _addHeaderName(key);
      } else {
        _addString(key);
      }
      _addColonSpace();
      _addHeaderValue(values[i]);
      _addCrlf();
    }
  }

  static Uint8List _takeScratch() =>
      Uint8List(_scratchPos)..setRange(0, _scratchPos, _scratch);

  /// Writes the scratch buffer to [socket] as one packet and reports the
  /// headers as sent. Returns the packet length.
  static int _sendScratch(Socket socket, void Function()? onHeadersSent) {
    final packet = _takeScratch();
    socket.add(packet);
    onHeadersSent?.call();
    return packet.length;
  }

  static StateError _contentLengthMismatch(int actual, int declared) =>
      StateError(
        'Response body length ($actual) does not match '
        'Content-Length ($declared)',
      );

  static Uint8List _chunkSizeLine(int length) =>
      ascii.encode('${length.toRadixString(16)}\r\n');

  /// Writes a response whose body is already in memory. The headers are in
  /// the scratch buffer; small bodies are coalesced into the same packet.
  static int _writeBufferedBody(
    Socket socket,
    Uint8List bufferedBytes, {
    required String requestMethod,
    required int? contentLength,
    required bool isBodylessStatus,
    required bool isChunked,
    required void Function()? onHeadersSent,
  }) {
    if (requestMethod == 'HEAD' || contentLength == 0 || isBodylessStatus) {
      return _sendScratch(socket, onHeadersSent);
    }

    if (!isChunked &&
        contentLength != null &&
        bufferedBytes.length != contentLength) {
      throw _contentLengthMismatch(bufferedBytes.length, contentLength);
    }

    if (bufferedBytes.isEmpty) {
      if (isChunked) {
        _addBytes(_chunkedEnd);
      }
      return _sendScratch(socket, onHeadersSent);
    }

    if (bufferedBytes.length <= $Limit.maxCoalesceChunkSize) {
      if (isChunked) {
        _addString('${bufferedBytes.length.toRadixString(16)}\r\n');
        _addBytes(bufferedBytes);
        _addBytes(_crlfChunkedEnd);
      } else {
        _addBytes(bufferedBytes);
      }
      return _sendScratch(socket, onHeadersSent);
    }

    // Large body: send it as its own buffer rather than copying it.
    if (isChunked) {
      _addString('${bufferedBytes.length.toRadixString(16)}\r\n');
    }
    var written = _sendScratch(socket, onHeadersSent);
    socket.add(bufferedBytes);
    written += bufferedBytes.length;
    if (isChunked) {
      socket.add(_crlfChunkedEnd);
      written += _crlfChunkedEnd.length;
    }
    return written;
  }

  static Future<int> _writeStreamResponse(
    Response response,
    Socket socket, {
    required Uint8List headerBytes,
    required String requestMethod,
    required int? contentLength,
    required bool isBodylessStatus,
    required bool isChunked,
    required void Function()? onHeadersSent,
  }) async {
    if (requestMethod == 'HEAD' || contentLength == 0 || isBodylessStatus) {
      socket.add(headerBytes);
      onHeadersSent?.call();
      if (requestMethod == 'HEAD') {
        await response.read().listen((_) {}).asFuture<void>();
      } else {
        unawaited(response.read().listen(null).cancel());
      }
      return headerBytes.length;
    }

    var written = 0;
    var bodyBytesWritten = 0;
    var headersSent = false;
    await for (final chunk in response.read()) {
      if (chunk.isEmpty) continue;
      bodyBytesWritten += chunk.length;
      if (!isChunked &&
          contentLength != null &&
          bodyBytesWritten > contentLength) {
        throw _contentLengthMismatch(bodyBytesWritten, contentLength);
      }
      if (headersSent) {
        written += _writeChunk(socket, chunk, isChunked: isChunked);
      } else {
        headersSent = true;
        written += _writeHeadersWithFirstChunk(
          socket,
          headerBytes,
          chunk,
          isChunked: isChunked,
        );
        onHeadersSent?.call();
      }
    }

    if (!isChunked &&
        contentLength != null &&
        bodyBytesWritten != contentLength) {
      throw _contentLengthMismatch(bodyBytesWritten, contentLength);
    }

    if (!headersSent) {
      socket.add(headerBytes);
      onHeadersSent?.call();
      written += headerBytes.length;
    }

    if (isChunked) {
      socket.add(_chunkedEnd);
      written += _chunkedEnd.length;
    }
    return written;
  }

  /// Sends the headers together with the first body chunk, in one packet when
  /// the chunk is small enough to be worth copying. Returns bytes written.
  static int _writeHeadersWithFirstChunk(
    Socket socket,
    Uint8List headerBytes,
    List<int> chunk, {
    required bool isChunked,
  }) {
    if (!isChunked) {
      if (chunk.length <= $Limit.maxCoalesceChunkSize) {
        final coalesced = Uint8List(headerBytes.length + chunk.length);
        coalesced.setRange(0, headerBytes.length, headerBytes);
        coalesced.setRange(headerBytes.length, coalesced.length, chunk);
        socket.add(coalesced);
        return coalesced.length;
      }
      socket.add(headerBytes);
      socket.add(chunk);
      return headerBytes.length + chunk.length;
    }

    final sizeLine = _chunkSizeLine(chunk.length);
    if (chunk.length <= $Limit.maxCoalesceChunkSize) {
      final coalesced = Uint8List(
        headerBytes.length + sizeLine.length + chunk.length + 2,
      );
      var pos = 0;
      coalesced.setRange(pos, pos += headerBytes.length, headerBytes);
      coalesced.setRange(pos, pos += sizeLine.length, sizeLine);
      coalesced.setRange(pos, pos += chunk.length, chunk);
      coalesced[pos] = $Chars.cr;
      coalesced[pos + 1] = $Chars.lf;
      socket.add(coalesced);
      return coalesced.length;
    }
    socket.add(headerBytes);
    socket.add(sizeLine);
    socket.add(chunk);
    socket.add(_crlf);
    return headerBytes.length + sizeLine.length + chunk.length + 2;
  }

  /// Sends a body chunk after the headers have gone out. Returns bytes
  /// written.
  static int _writeChunk(
    Socket socket,
    List<int> chunk, {
    required bool isChunked,
  }) {
    if (!isChunked) {
      socket.add(chunk);
      return chunk.length;
    }
    final sizeLine = _chunkSizeLine(chunk.length);
    if (chunk.length <= $Limit.maxCoalesceChunkSize) {
      final builder = BytesBuilder(copy: false);
      builder.add(sizeLine);
      builder.add(chunk);
      builder.add(_crlf);
      final bytes = builder.takeBytes();
      socket.add(bytes);
      return bytes.length;
    }
    socket.add(sizeLine);
    socket.add(chunk);
    socket.add(_crlf);
    return sizeLine.length + chunk.length + 2;
  }

  static String _getStatusPhrase(int statusCode) => switch (statusCode) {
    200 => 'OK',
    201 => 'Created',
    204 => 'No Content',
    301 => 'Moved Permanently',
    302 => 'Found',
    304 => 'Not Modified',
    400 => 'Bad Request',
    401 => 'Unauthorized',
    403 => 'Forbidden',
    404 => 'Not Found',
    500 => 'Internal Server Error',
    _ => 'Unknown',
  };
}
