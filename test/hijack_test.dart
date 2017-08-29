// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:shelf/shelf.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'test_util.dart';

void main() {
  test('hijacking a non-hijackable request throws a StateError', () {
    expect(() => new Request('GET', localhostUri).hijack((_) => null),
        throwsStateError);
  });

  test(
      'hijacking a hijackable request throws a HijackException and calls '
      'onHijack', () {
    var request = new Request('GET', localhostUri,
        onHijack: expectAsync1((void callback(channel)) {
      var streamController = new StreamController<List<int>>();
      streamController.add([1, 2, 3]);
      streamController.close();

      var sinkController = new StreamController();
      expect(sinkController.stream.first, completion(equals([4, 5, 6])));

      callback(new StreamChannel(streamController.stream, sinkController));
    }));

    expect(
        () => request.hijack(expectAsync1((channel) {
              expect(channel.stream.first, completion(equals([1, 2, 3])));
              channel.sink.add([4, 5, 6]);
              channel.sink.close();
            })),
        throwsA(new isInstanceOf<HijackException>()));
  });

  test('hijacking a hijackable request twice throws a StateError', () {
    // Assert that the [onHijack] callback is only called once.
    var request = new Request('GET', localhostUri,
        onHijack: expectAsync1((_) => null, count: 1));

    expect(() => request.hijack((_) => null),
        throwsA(new isInstanceOf<HijackException>()));

    expect(() => request.hijack((_) => null), throwsStateError);
  });

  group('calling change', () {
    test('hijacking a non-hijackable request throws a StateError', () {
      var request = new Request('GET', localhostUri);
      var newRequest = request.change();
      expect(() => newRequest.hijack((_) => null), throwsStateError);
    });

    test(
        'hijacking a hijackable request throws a HijackException and calls '
        'onHijack', () {
      var request = new Request('GET', localhostUri,
          onHijack: expectAsync1((callback(channel)) {
        var streamController = new StreamController<List<int>>();
        streamController.add([1, 2, 3]);
        streamController.close();

        var sinkController = new StreamController();
        expect(sinkController.stream.first, completion(equals([4, 5, 6])));

        callback(new StreamChannel(streamController.stream, sinkController));
      }));

      var newRequest = request.change();

      expect(
          () => newRequest.hijack(expectAsync1((channel) {
                expect(channel.stream.first, completion(equals([1, 2, 3])));
                channel.sink.add([4, 5, 6]);
                channel.sink.close();
              })),
          throwsA(new isInstanceOf<HijackException>()));
    });

    test(
        'hijacking the original request after calling change throws a '
        'StateError', () {
      // Assert that the [onHijack] callback is only called once.
      var request = new Request('GET', localhostUri,
          onHijack: expectAsync1((_) => null, count: 1));

      var newRequest = request.change();

      expect(() => newRequest.hijack((_) => null),
          throwsA(new isInstanceOf<HijackException>()));

      expect(() => request.hijack((_) => null), throwsStateError);
    });
  });
}
