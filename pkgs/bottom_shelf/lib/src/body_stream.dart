// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

/// A stream that consumes a fixed number of bytes from an underlying subscription.
final class FixedLengthBodyStream extends Stream<Uint8List> {
  final StreamSubscription<Uint8List> _subscription;
  final int _contentLength;
  int _consumed = 0;

  final _controller = StreamController<Uint8List>(sync: true);

  FixedLengthBodyStream(
      this._subscription, this._contentLength, Uint8List? initial) {
    _controller.onListen = () {
      if (initial != null && initial.isNotEmpty) {
        _handleData(initial);
      }
      if (_consumed < _contentLength) {
        _subscription.resume();
      } else {
        _controller.close();
      }
    };
    _controller.onPause = () => _subscription.pause();
    _controller.onResume = () => _subscription.resume();
    _controller.onCancel = () {
      // Note: We don't cancel the underlying subscription because we might
      // want to continue using the socket for keep-alive.
      // But we must drain it if we want to continue.
    };
  }

  void _handleData(Uint8List data) {
    final remaining = _contentLength - _consumed;
    if (data.length <= remaining) {
      _controller.add(data);
      _consumed += data.length;
    } else {
      _controller.add(Uint8List.sublistView(data, 0, remaining));
      _consumed += remaining;
      // Note: The rest of 'data' belongs to the next request (pipelining)
    }

    if (_consumed >= _contentLength) {
      _controller.close();
      _subscription.pause();
    }
  }

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _controller.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}
