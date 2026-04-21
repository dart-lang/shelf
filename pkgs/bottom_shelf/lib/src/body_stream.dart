// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'constants.dart';
import 'utils.dart';

/// A common interface for body controllers.
abstract interface class BodyController {
  Stream<Uint8List> get stream;
  bool get isDone;
  Uint8List add(Uint8List data);
  void close();
  Uint8List takeBufferedData();
}

/// A stream controller for a fixed-length HTTP request body.
final class FixedLengthBodyController implements BodyController {
  final int _contentLength;
  int _consumed = 0;
  late final StreamController<Uint8List> _controller;
  final void Function() _onDone;

  final _bufferedChunks = <Uint8List>[];
  bool _hasListener = false;
  bool _isClosed = false;

  FixedLengthBodyController(
    this._contentLength,
    this._onDone, {
    void Function()? onPause,
    void Function()? onResume,
  }) {
    _controller = StreamController<Uint8List>(
      sync: true,
      onListen: () {
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
      },
      onPause: onPause,
      onResume: onResume,
    );
  }

  @override
  Stream<Uint8List> get stream => _controller.stream;

  @override
  bool get isDone => _consumed >= _contentLength;

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

  void _addChunk(Uint8List chunk) {
    if (_hasListener) {
      if (!_controller.isClosed) {
        _controller.add(chunk);
      }
    } else {
      _bufferedChunks.add(chunk);
    }
  }

  void _close() {
    if (!_isClosed) {
      _isClosed = true;
      if (_hasListener && !_controller.isClosed) {
        _controller.close();
      }
      _onDone();
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
final class ChunkedBodyController implements BodyController {
  static const int _stateSize = 0;
  static const int _stateExt = 1;
  static const int _stateData = 2;
  static const int _stateDataCRLF = 3;
  static const int _stateTrailers = 4;

  int _state = _stateSize;
  int _chunkSize = 0;
  int _chunkBytesRead = 0;
  int _trailerState = 0;

  bool _isDone = false;

  late final StreamController<Uint8List> _controller;
  final void Function() _onDone;

  final _bufferedChunks = <Uint8List>[];
  bool _hasListener = false;
  bool _isClosed = false;

  ChunkedBodyController(
    this._onDone, {
    void Function()? onPause,
    void Function()? onResume,
  }) {
    _controller = StreamController<Uint8List>(
      sync: true,
      onListen: () {
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
      },
      onPause: onPause,
      onResume: onResume,
    );
  }

  @override
  Stream<Uint8List> get stream => _controller.stream;

  @override
  bool get isDone => _isDone;

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

  @override
  Uint8List add(Uint8List data) {
    if (_isDone) return data;

    var pos = 0;
    while (pos < data.length) {
      if (_isDone) {
        return Uint8List.sublistView(data, pos);
      }

      switch (_state) {
        case _stateSize:
          final byte = data[pos];
          if (byte == $Chars.cr) {
            // CR, ignore
            pos++;
          } else if (byte == $Chars.lf) {
            // LF, end of size
            pos++;
            if (_chunkSize == 0) {
              _state = _stateTrailers;
            } else {
              _chunkBytesRead = 0;
              _state = _stateData;
            }
          } else if (byte == $Chars.semicolon) {
            // ';' start of extensions
            pos++;
            _state = _stateExt;
          } else {
            // hex digit
            final hex = parseHex(byte);
            if (hex == -1) throw const HttpException('Invalid chunk size');
            _chunkSize = (_chunkSize << 4) + hex;
            pos++;
          }
        case _stateExt:
          final byte = data[pos];
          if (byte == $Chars.lf) {
            // LF, end of ext
            pos++;
            if (_chunkSize == 0) {
              _state = _stateTrailers;
            } else {
              _chunkBytesRead = 0;
              _state = _stateData;
            }
          } else {
            pos++;
          }
        case _stateData:
          final remainingInChunk = _chunkSize - _chunkBytesRead;
          final remainingInData = data.length - pos;
          final take = remainingInChunk < remainingInData
              ? remainingInChunk
              : remainingInData;

          _addChunk(Uint8List.sublistView(data, pos, pos + take));

          _chunkBytesRead += take;
          pos += take;

          if (_chunkBytesRead == _chunkSize) {
            _state = _stateDataCRLF;
          }
        case _stateDataCRLF:
          final byte = data[pos];
          if (byte == $Chars.lf) {
            // LF, end of CRLF
            pos++;
            _chunkSize = 0;
            _state = _stateSize;
          } else {
            pos++;
          }
        case _stateTrailers:
          final byte = data[pos];
          pos++;
          if (byte == $Chars.cr) {
            // ignore
          } else if (byte == $Chars.lf) {
            if (_trailerState == 0) {
              // empty line
              _isDone = true;
              _close();
              return Uint8List.sublistView(data, pos);
            } else {
              // end of a trailer line
              _trailerState = 0;
            }
          } else {
            _trailerState = 1; // not empty
          }
      }
    }
    return Uint8List(0);
  }

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
  void close() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
