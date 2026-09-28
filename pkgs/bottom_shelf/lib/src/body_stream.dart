// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'constants.dart';
import 'exceptions.dart';
import 'utils.dart';

/// A common interface for body controllers.
abstract interface class BodyController {
  Stream<Uint8List> get stream;
  bool get isDone;
  Uint8List add(Uint8List data);
  void close();
  void addError(Object error);
  Uint8List takeBufferedData();
}

/// Shared buffering for body controllers.
///
/// Chunks added before the handler listens are held and replayed on listen;
/// a close that happens before listen is deferred to listen as well.
abstract base class _BufferingBodyController implements BodyController {
  late final StreamController<Uint8List> _controller;
  final void Function() _onDone;

  final _bufferedChunks = <Uint8List>[];
  bool _hasListener = false;
  bool _isClosed = false;

  _BufferingBodyController(
    this._onDone, {
    void Function()? onPause,
    void Function()? onResume,
  }) {
    _controller = StreamController<Uint8List>(
      sync: true,
      onListen: _onListen,
      onPause: onPause,
      onResume: onResume,
    );
  }

  void _onListen() {
    _hasListener = true;
    for (var chunk in _bufferedChunks) {
      if (!_controller.isClosed) {
        _controller.add(chunk);
      }
    }
    _bufferedChunks.clear();
    if (_isClosed && !_controller.isClosed) {
      _controller.close();
    }
  }

  @override
  Stream<Uint8List> get stream => _controller.stream;

  @override
  Uint8List takeBufferedData() {
    if (_bufferedChunks.isEmpty) return Uint8List(0);
    var totalLength = 0;
    for (final chunk in _bufferedChunks) {
      totalLength += chunk.length;
    }
    final result = Uint8List(totalLength);
    var offset = 0;
    for (var chunk in _bufferedChunks) {
      result.setAll(offset, chunk);
      offset += chunk.length;
    }
    _bufferedChunks.clear();
    return result;
  }

  void _addChunk(Uint8List chunk) {
    if (_hasListener) {
      if (!_controller.isClosed) {
        _controller.add(chunk);
      }
    } else {
      _bufferedChunks.add(chunk);
    }
  }

  /// The body has been fully received: close the stream (once someone is
  /// listening) and report completion.
  void _close() {
    if (!_isClosed) {
      _isClosed = true;
      if (_hasListener && !_controller.isClosed) {
        _controller.close();
      }
      _onDone();
    }
  }

  @override
  void addError(Object error) {
    if (!_controller.isClosed) {
      _controller.addError(error);
    }
  }
}

/// A stream controller for a fixed-length HTTP request body.
final class FixedLengthBodyController extends _BufferingBodyController {
  final int _contentLength;
  int _consumed = 0;

  FixedLengthBodyController(
    this._contentLength,
    super.onDone, {
    super.onPause,
    super.onResume,
  });

  @override
  bool get isDone => _consumed >= _contentLength;

  /// Adds [data] to the body stream.
  ///
  /// Returns any remaining data that was not part of the body (pipelining).
  @override
  Uint8List add(Uint8List data) {
    final remainingInBody = _contentLength - _consumed;
    if (data.length <= remainingInBody) {
      _addChunk(data);
      _consumed += data.length;
      if (_consumed == _contentLength) {
        _close();
      }
      return Uint8List(0);
    } else {
      _addChunk(Uint8List.sublistView(data, 0, remainingInBody));
      _consumed = _contentLength;
      _close();
      return Uint8List.sublistView(data, remainingInBody);
    }
  }

  /// Closes the stream and stops sending data to listeners.
  /// The controller will still track consumption for draining purposes.
  @override
  void close() {
    if (!_controller.isClosed) {
      _controller.close();
      // We don't call _onDone here because we still need to wait for
      // the actual bytes to be 'add'ed from the socket.
    }
  }
}

/// A stream controller for a chunked HTTP request body.
final class ChunkedBodyController extends _BufferingBodyController {
  static const int _stateSize = 0;
  static const int _stateData = 1;
  static const int _stateDataCR = 2;
  static const int _stateDataCRLF = 3;
  static const int _stateTrailers = 4;

  int _state = _stateSize;
  int _chunkSize = 0;
  int _chunkBytesRead = 0;

  /// Whether the current trailer line has any content yet; the blank line
  /// that ends the trailers is an LF seen while this is `false`.
  bool _inTrailerLine = false;

  bool _isDone = false;

  ChunkedBodyController(super.onDone, {super.onPause, super.onResume});

  @override
  bool get isDone => _isDone;

  @override
  Uint8List add(Uint8List data) {
    if (_isDone) return data;

    var pos = 0;
    while (pos < data.length) {
      switch (_state) {
        case _stateSize:
          _onSizeByte(data[pos++]);
        case _stateData:
          pos = _takeChunkData(data, pos);
        case _stateDataCR:
          _expectAfterChunkData(data[pos++], $Chars.cr);
          _state = _stateDataCRLF;
        case _stateDataCRLF:
          _expectAfterChunkData(data[pos++], $Chars.lf);
          _chunkSize = 0;
          _state = _stateSize;
        case _stateTrailers:
          if (_onTrailerByte(data[pos++])) {
            _isDone = true;
            _close();
            return Uint8List.sublistView(data, pos);
          }
      }
    }
    return Uint8List(0);
  }

  /// Accumulates the hex chunk-size line; LF ends it.
  @pragma('vm:prefer-inline')
  void _onSizeByte(int byte) {
    if (byte == $Chars.cr) return;
    if (byte == $Chars.lf) {
      if (_chunkSize == 0) {
        _state = _stateTrailers;
      } else {
        _chunkBytesRead = 0;
        _state = _stateData;
      }
      return;
    }
    if (byte == $Chars.semicolon) {
      // TODO: Support chunk extensions?
      throw BadRequestException.fromResponse(ErrorResponse.notImplemented);
    }
    final hex = parseHex(byte);
    if (hex < 0) {
      throw const BadRequestException('Invalid chunk size');
    }
    if (_chunkSize > $Limit.maxChunkSizeBeforeShift) {
      throw const BadRequestException('Chunk size too large');
    }
    _chunkSize = (_chunkSize << 4) + hex;
  }

  /// Forwards as much of the current chunk as [data] holds from [pos] and
  /// returns the position after it.
  @pragma('vm:prefer-inline')
  int _takeChunkData(Uint8List data, int pos) {
    final remainingInChunk = _chunkSize - _chunkBytesRead;
    final remainingInData = data.length - pos;
    final take = remainingInChunk < remainingInData
        ? remainingInChunk
        : remainingInData;

    _addChunk(Uint8List.sublistView(data, pos, pos + take));
    _chunkBytesRead += take;
    if (_chunkBytesRead == _chunkSize) {
      _state = _stateDataCR;
    }
    return pos + take;
  }

  @pragma('vm:prefer-inline')
  static void _expectAfterChunkData(int byte, int expected) {
    if (byte != expected) {
      throw const BadRequestException('CRLF expected after chunk data');
    }
  }

  /// Consumes one byte of the trailer section. Returns `true` on the blank
  /// line that ends the body.
  @pragma('vm:prefer-inline')
  bool _onTrailerByte(int byte) {
    if (byte == $Chars.cr) return false;
    if (byte == $Chars.lf) {
      if (!_inTrailerLine) return true;
      _inTrailerLine = false;
      return false;
    }
    _inTrailerLine = true;
    return false;
  }

  @override
  void close() {
    if (!_isDone && !_controller.isClosed) {
      _controller.addError(
        const BadRequestException('Incomplete chunked body'),
      );
    }
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
