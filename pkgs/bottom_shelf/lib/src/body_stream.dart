// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

/// A stream controller for a fixed-length HTTP request body.
final class FixedLengthBodyController {
  final int _contentLength;
  int _consumed = 0;
  final _controller = StreamController<Uint8List>(sync: true);
  final void Function() _onDone;

  FixedLengthBodyController(this._contentLength, this._onDone);

  Stream<Uint8List> get stream => _controller.stream;

  bool get isDone => _consumed >= _contentLength;

  /// Adds [data] to the body stream.
  ///
  /// Returns any remaining data that was not part of the body (pipelining).
  Uint8List add(Uint8List data) {
    final remainingInBody = _contentLength - _consumed;
    if (data.length <= remainingInBody) {
      if (!_controller.isClosed) {
        _controller.add(data);
      }
      _consumed += data.length;
      if (_consumed == _contentLength) {
        _close();
      }
      return Uint8List(0);
    } else {
      if (!_controller.isClosed) {
        _controller.add(Uint8List.sublistView(data, 0, remainingInBody));
      }
      _consumed = _contentLength;
      _close();
      return Uint8List.sublistView(data, remainingInBody);
    }
  }

  void _close() {
    if (!_controller.isClosed) {
      _controller.close();
      _onDone();
    }
  }

  /// Closes the stream and stops sending data to listeners.
  /// The controller will still track consumption for draining purposes.
  void close() {
    if (!_controller.isClosed) {
      _controller.close();
      // We don't call _onDone here because we still need to wait for
      // the actual bytes to be 'add'ed from the socket.
    }
  }
}
