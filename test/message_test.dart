// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library shelf.message_test;

import 'dart:async';
import 'dart:convert';

import 'package:shelf/src/message.dart';
import 'package:test/test.dart';

import 'test_util.dart';
import 'package:shelf/src/response.dart';

class _TestMessage extends Message {
  _TestMessage(Map<String, String> headers, Map<String, Object> context, body,
      Encoding encoding)
      : super(body, headers: headers, context: context, encoding: encoding);

  Message change({Map<String, String> headers, Map<String, Object> context,
      body}) {
    throw new UnimplementedError();
  }
}

Message _createMessage({Map<String, String> headers,
    Map<String, Object> context, body, Encoding encoding}) {
  return new _TestMessage(headers, context, body, encoding);
}

void main() {
  group('headers', () {
    test('message headers are case insensitive', () {
      var message = _createMessage(headers: {'foo': 'bar'});

      expect(message.headers, containsPair('foo', 'bar'));
      expect(message.headers, containsPair('Foo', 'bar'));
      expect(message.headers, containsPair('FOO', 'bar'));
    });

    test('null header value becomes empty, immutable', () {
      var message = _createMessage();
      expect(message.headers, isEmpty);
      expect(() => message.headers['h1'] = 'value1', throwsUnsupportedError);
    });

    test('headers are immutable', () {
      var message = _createMessage(headers: {'h1': 'value1'});
      expect(() => message.headers['h1'] = 'value1', throwsUnsupportedError);
      expect(() => message.headers['h1'] = 'value2', throwsUnsupportedError);
      expect(() => message.headers['h2'] = 'value2', throwsUnsupportedError);
    });
  });

  group('context', () {
    test('is accessible', () {
      var message = _createMessage(context: {'foo': 'bar'});
      expect(message.context, containsPair('foo', 'bar'));
    });

    test('null context value becomes empty and immutable', () {
      var message = _createMessage();
      expect(message.context, isEmpty);
      expect(() => message.context['key'] = 'value', throwsUnsupportedError);
    });

    test('is immutable', () {
      var message = _createMessage(context: {'key': 'value'});
      expect(() => message.context['key'] = 'value', throwsUnsupportedError);
      expect(() => message.context['key2'] = 'value', throwsUnsupportedError);
    });
  });

  group("readAsString", () {
    test("supports a null body", () {
      var request = _createMessage();
      expect(request.readAsString(), completion(equals("")));
    });

    test("supports a Stream<List<int>> body", () {
      var controller = new StreamController();
      var request = _createMessage(body: controller.stream);
      expect(request.readAsString(), completion(equals("hello, world")));

      controller.add(HELLO_BYTES);
      return new Future(() {
        controller
          ..add(WORLD_BYTES)
          ..close();
      });
    });

    test("defaults to UTF-8", () {
      var request = _createMessage(body: new Stream.fromIterable([[195, 168]]));
      expect(request.readAsString(), completion(equals("è")));
    });

    test("the content-type header overrides the default", () {
      var request = _createMessage(
          headers: {'content-type': 'text/plain; charset=iso-8859-1'},
          body: new Stream.fromIterable([[195, 168]]));
      expect(request.readAsString(), completion(equals("Ã¨")));
    });

    test("an explicit encoding overrides the content-type header", () {
      var request = _createMessage(
          headers: {'content-type': 'text/plain; charset=iso-8859-1'},
          body: new Stream.fromIterable([[195, 168]]));
      expect(request.readAsString(LATIN1), completion(equals("Ã¨")));
    });
  });

  group("read", () {
    test("supports a null body", () {
      var request = _createMessage();
      expect(request.read().toList(), completion(isEmpty));
    });

    test("supports a Stream<List<int>> body", () {
      var controller = new StreamController();
      var request = _createMessage(body: controller.stream);
      expect(request.read().toList(),
          completion(equals([HELLO_BYTES, WORLD_BYTES])));

      controller.add(HELLO_BYTES);
      return new Future(() {
        controller
          ..add(WORLD_BYTES)
          ..close();
      });
    });

    test("throws when calling read()/readAsString() multiple times", () {
      var request;

      request = _createMessage();
      expect(request.read().toList(), completion(isEmpty));
      expect(() => request.read(), throwsStateError);

      request = _createMessage();
      expect(request.readAsString(), completion(isEmpty));
      expect(() => request.readAsString(), throwsStateError);

      request = _createMessage();
      expect(request.readAsString(), completion(isEmpty));
      expect(() => request.read(), throwsStateError);

      request = _createMessage();
      expect(request.read().toList(), completion(isEmpty));
      expect(() => request.readAsString(), throwsStateError);
    });
  });

  group("contentLength", () {
    test("is null without a content-length header", () {
      var request = _createMessage();
      expect(request.contentLength, isNull);
    });

    test("comes from the content-length header", () {
      var request = _createMessage(headers: {'content-length': '42'});
      expect(request.contentLength, 42);
    });
  });

  group("mimeType", () {
    test("is null without a content-type header", () {
      expect(_createMessage().mimeType, isNull);
    });

    test("comes from the content-type header", () {
      expect(_createMessage(headers: {'content-type': 'text/plain'}).mimeType,
          equals('text/plain'));
    });

    test("doesn't include parameters", () {
      expect(_createMessage(
          headers: {
        'content-type': 'text/plain; foo=bar; bar=baz'
      }).mimeType, equals('text/plain'));
    });
  });

  group("encoding", () {
    test("is null without a content-type header", () {
      expect(_createMessage().encoding, isNull);
    });

    test("is null without a charset parameter", () {
      expect(_createMessage(headers: {'content-type': 'text/plain'}).encoding,
          isNull);
    });

    test("is null with an unrecognized charset parameter", () {
      expect(_createMessage(
              headers: {'content-type': 'text/plain; charset=fblthp'}).encoding,
          isNull);
    });

    test("comes from the content-type charset parameter", () {
      expect(_createMessage(
          headers: {
        'content-type': 'text/plain; charset=iso-8859-1'
      }).encoding, equals(LATIN1));
    });

    test("defaults to encoding a String as UTF-8", () {
      expect(_createMessage(body: "è").read().toList(),
          completion(equals([[195, 168]])));
    });

    test("uses the explicit encoding if available", () {
      expect(_createMessage(body: "è", encoding: LATIN1).read().toList(),
          completion(equals([[232]])));
    });

    test("adds an explicit encoding to the content-type", () {
      var request = _createMessage(
          body: "è", encoding: LATIN1, headers: {'content-type': 'text/plain'});
      expect(request.headers,
          containsPair('content-type', 'text/plain; charset=iso-8859-1'));
    });

    test("sets an absent content-type to application/octet-stream in order to "
        "set the charset", () {
      var request = _createMessage(body: "è", encoding: LATIN1);
      expect(request.headers, containsPair(
          'content-type', 'application/octet-stream; charset=iso-8859-1'));
    });

    test("overwrites an existing charset if given an explicit encoding", () {
      var request = _createMessage(
          body: "è",
          encoding: LATIN1,
          headers: {'content-type': 'text/plain; charset=whatever'});
      expect(request.headers,
          containsPair('content-type', 'text/plain; charset=iso-8859-1'));
    });
  });

  group("content type should be preserved when setting encoding", () {
    final contentType = 'application/atom+xml';
    final charset = 'charset=utf-8';

    test("when encoding is not set", () {
      final response = new Response.ok("", headers: {
        'content-type' : contentType
      });

      expect(response.headers['content-type'], contentType);
    });

    test("when encoding is set", () {
      final response = new Response.ok("", headers: {
        'content-type' : contentType,
      }, encoding: UTF8);

      expect(response.headers['content-type'], '$contentType; $charset');
    });

    test("when encoding is set", () {
      final response = new Response.ok("", headers: {
        'content-type' : contentType,
      }, encoding: UTF8);

      expect(response.headers['content-type'], '$contentType; $charset');
    });

    test("when content-type is specified in another case", () {
      final response = new Response.ok("", headers: {
        'Content-Type' : contentType,
      }, encoding: UTF8);

      expect(response.headers['content-type'], '$contentType; $charset');
    });
  });
}
