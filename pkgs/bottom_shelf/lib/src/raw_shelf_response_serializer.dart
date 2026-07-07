// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

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

  static Future<void> writeResponse(
    Response response,
    Socket socket, {
    required bool keepAlive,
    required String requestMethod,
    String? poweredBy,
  }) async {
    var hasContentLength = false;
    var hasTransferEncoding = false;
    var hasConnection = false;
    var hasDate = false;
    var hasPoweredBy = false;
    int? contentLength;

    _scratchPos = 0;
    _addBytes(_statusLine(response.statusCode));

    response.headersAll.forEach((key, values) {
      if (values.isEmpty) return;
      switch (key.length) {
        case 14 when _equalsIgnoreAsciiCase(key, 'content-length'):
          hasContentLength = true;
          contentLength = int.tryParse(values.first);
        case 17 when _equalsIgnoreAsciiCase(key, 'transfer-encoding'):
          hasTransferEncoding = true;
        case 10 when _equalsIgnoreAsciiCase(key, 'connection'):
          hasConnection = true;
        case 4 when _equalsIgnoreAsciiCase(key, 'date'):
          hasDate = true;
        case 12 when _equalsIgnoreAsciiCase(key, 'x-powered-by'):
          hasPoweredBy = true;
      }
      _addHeaderName(key);
      _ensure(2);
      _scratch[_scratchPos++] = $Chars.colon;
      _scratch[_scratchPos++] = $Chars.sp;
      for (var i = 0; i < values.length; i++) {
        if (i > 0) _addString(', ');
        _addHeaderValue(values[i]);
      }
      _addCrlf();
    });

    // `Message.contentLength` derives from the `content-length` header, so
    // when the header is absent the body length is unknown: chunk it.
    final isChunked = !hasContentLength;

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

    _addCrlf();

    // Materialize before any await: the static scratch buffer is shared
    // across all connections in this isolate and interleaving writeResponse
    // calls resume at await boundaries.
    final headerBytes = Uint8List(_scratchPos)
      ..setRange(0, _scratchPos, _scratch);

    if (requestMethod == 'HEAD' || contentLength == 0) {
      socket.add(headerBytes);
      if (requestMethod == 'HEAD') {
        await response.read().listen((_) {}).asFuture<void>();
      }
    } else {
      var isFirst = true;
      await for (final chunk in response.read()) {
        if (chunk.isEmpty) continue;
        if (isFirst) {
          isFirst = false;
          if (isChunked) {
            final sizeLine = ascii.encode(
              '${chunk.length.toRadixString(16)}\r\n',
            );
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
          } else {
            final coalesced = Uint8List(headerBytes.length + chunk.length);
            coalesced.setRange(0, headerBytes.length, headerBytes);
            coalesced.setRange(headerBytes.length, coalesced.length, chunk);
            socket.add(coalesced);
          }
        } else {
          if (isChunked) {
            final builder = BytesBuilder(copy: false);
            builder.add(ascii.encode('${chunk.length.toRadixString(16)}\r\n'));
            builder.add(chunk);
            builder.add(_crlf);
            socket.add(builder.takeBytes());
          } else {
            socket.add(chunk);
          }
        }
      }

      if (isFirst) {
        socket.add(headerBytes);
      }

      if (isChunked) {
        socket.add(_chunkedEnd);
      }
    }

    await socket.flush();
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
