// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'test_util.dart';

Request _request({Map<String, String> headers, body, Encoding encoding}) {
  return new Request("GET", localhostUri,
      headers: headers, body: body, encoding: encoding);
}

void main() {
  group('constructor', () {
    test('protocolVersion defaults to "1.1"', () {
      var request = new Request('GET', localhostUri);
      expect(request.protocolVersion, '1.1');
    });

    test('provide non-default protocolVersion', () {
      var request = new Request('GET', localhostUri, protocolVersion: '1.0');
      expect(request.protocolVersion, '1.0');
    });

    group("url", () {
      test("defaults to the requestedUri's relativized path and query", () {
        var request =
            new Request('GET', Uri.parse("http://localhost/foo/bar?q=1"));
        expect(request.url, equals(Uri.parse("foo/bar?q=1")));
      });

      test("is inferred from handlerPath if possible", () {
        var request = new Request(
            'GET', Uri.parse("http://localhost/foo/bar?q=1"),
            handlerPath: '/foo/');
        expect(request.url, equals(Uri.parse("bar?q=1")));
      });

      test("uses the given value if passed", () {
        var request = new Request(
            'GET', Uri.parse("http://localhost/foo/bar?q=1"),
            url: Uri.parse("bar?q=1"));
        expect(request.url, equals(Uri.parse("bar?q=1")));
      });

      test("may be empty", () {
        var request = new Request('GET', Uri.parse("http://localhost/foo/bar"),
            url: Uri.parse(""));
        expect(request.url, equals(Uri.parse("")));
      });
    });

    group("handlerPath", () {
      test("defaults to '/'", () {
        var request = new Request('GET', Uri.parse("http://localhost/foo/bar"));
        expect(request.handlerPath, equals('/'));
      });

      test("is inferred from url if possible", () {
        var request = new Request(
            'GET', Uri.parse("http://localhost/foo/bar?q=1"),
            url: Uri.parse("bar?q=1"));
        expect(request.handlerPath, equals("/foo/"));
      });

      test("uses the given value if passed", () {
        var request = new Request(
            'GET', Uri.parse("http://localhost/foo/bar?q=1"),
            handlerPath: '/foo/');
        expect(request.handlerPath, equals("/foo/"));
      });

      test("adds a trailing slash to the given value if necessary", () {
        var request = new Request(
            'GET', Uri.parse("http://localhost/foo/bar?q=1"),
            handlerPath: '/foo');
        expect(request.handlerPath, equals("/foo/"));
        expect(request.url, equals(Uri.parse("bar?q=1")));
      });

      test("may be a single slash", () {
        var request = new Request(
            'GET', Uri.parse("http://localhost/foo/bar?q=1"),
            handlerPath: '/');
        expect(request.handlerPath, equals("/"));
        expect(request.url, equals(Uri.parse("foo/bar?q=1")));
      });
    });

    group("errors", () {
      group('requestedUri', () {
        test('must be absolute', () {
          expect(() => new Request('GET', Uri.parse('/path')),
              throwsArgumentError);
        });

        test('may not have a fragment', () {
          expect(() {
            new Request('GET', Uri.parse('http://localhost/#fragment'));
          }, throwsArgumentError);
        });
      });

      group('url', () {
        test('must be relative', () {
          expect(() {
            new Request('GET', Uri.parse('http://localhost/test'),
                url: Uri.parse('http://localhost/test'));
          }, throwsArgumentError);
        });

        test('may not be root-relative', () {
          expect(() {
            new Request('GET', Uri.parse('http://localhost/test'),
                url: Uri.parse('/test'));
          }, throwsArgumentError);
        });

        test('may not have a fragment', () {
          expect(() {
            new Request('GET', Uri.parse('http://localhost/test'),
                url: Uri.parse('test#fragment'));
          }, throwsArgumentError);
        });

        test('must be a suffix of requestedUri', () {
          expect(() {
            new Request('GET', Uri.parse('http://localhost/dir/test'),
                url: Uri.parse('dir'));
          }, throwsArgumentError);
        });

        test('must have the same query parameters as requestedUri', () {
          expect(() {
            new Request('GET', Uri.parse('http://localhost/test?q=1&r=2'),
                url: Uri.parse('test?q=2&r=1'));
          }, throwsArgumentError);

          // Order matters for query parameters.
          expect(() {
            new Request('GET', Uri.parse('http://localhost/test?q=1&r=2'),
                url: Uri.parse('test?r=2&q=1'));
          }, throwsArgumentError);
        });
      });

      group('handlerPath', () {
        test('must be a prefix of requestedUri', () {
          expect(() {
            new Request('GET', Uri.parse('http://localhost/dir/test'),
                handlerPath: '/test');
          }, throwsArgumentError);
        });

        test('must start with "/"', () {
          expect(() {
            new Request('GET', Uri.parse('http://localhost/test'),
                handlerPath: 'test');
          }, throwsArgumentError);
        });

        test('must be the requestedUri path if url is empty', () {
          expect(() {
            new Request('GET', Uri.parse('http://localhost/test'),
                handlerPath: '/', url: Uri.parse(''));
          }, throwsArgumentError);
        });
      });

      group('handlerPath + url must', () {
        test('be requestedUrl path', () {
          expect(() {
            new Request('GET', Uri.parse('http://localhost/foo/bar/baz'),
                handlerPath: '/foo/', url: Uri.parse('baz'));
          }, throwsArgumentError);
        });

        test('be on a path boundary', () {
          expect(() {
            new Request('GET', Uri.parse('http://localhost/foo/bar/baz'),
                handlerPath: '/foo/ba', url: Uri.parse('r/baz'));
          }, throwsArgumentError);
        });
      });
    });
  });

  group("ifModifiedSince", () {
    test("is null without an If-Modified-Since header", () {
      var request = _request();
      expect(request.ifModifiedSince, isNull);
    });

    test("comes from the Last-Modified header", () {
      var request = _request(
          headers: {'if-modified-since': 'Sun, 06 Nov 1994 08:49:37 GMT'});
      expect(request.ifModifiedSince,
          equals(DateTime.parse("1994-11-06 08:49:37z")));
    });
  });

  group('change', () {
    test('with no arguments returns instance with equal values', () {
      var controller = new StreamController();

      var uri = Uri.parse('https://test.example.com/static/file.html');

      var request = new Request('GET', uri,
          protocolVersion: '2.0',
          headers: {'header1': 'header value 1'},
          url: Uri.parse('file.html'),
          handlerPath: '/static/',
          body: controller.stream,
          context: {'context1': 'context value 1'});

      var copy = request.change();

      expect(copy.method, request.method);
      expect(copy.requestedUri, request.requestedUri);
      expect(copy.protocolVersion, request.protocolVersion);
      expect(copy.headers, same(request.headers));
      expect(copy.url, request.url);
      expect(copy.handlerPath, request.handlerPath);
      expect(copy.context, same(request.context));
      expect(copy.readAsString(), completion('hello, world'));

      controller.add(helloBytes);
      return new Future(() {
        controller
          ..add(worldBytes)
          ..close();
      });
    });

    group('with path', () {
      test('updates handlerPath and url', () {
        var uri = Uri.parse('https://test.example.com/static/dir/file.html');
        var request = new Request('GET', uri,
            handlerPath: '/static/', url: Uri.parse('dir/file.html'));
        var copy = request.change(path: 'dir');

        expect(copy.handlerPath, '/static/dir/');
        expect(copy.url, Uri.parse('file.html'));
      });

      test('allows a trailing slash', () {
        var uri = Uri.parse('https://test.example.com/static/dir/file.html');
        var request = new Request('GET', uri,
            handlerPath: '/static/', url: Uri.parse('dir/file.html'));
        var copy = request.change(path: 'dir/');

        expect(copy.handlerPath, '/static/dir/');
        expect(copy.url, Uri.parse('file.html'));
      });

      test('throws if path does not match existing uri', () {
        var uri = Uri.parse('https://test.example.com/static/dir/file.html');
        var request = new Request('GET', uri,
            handlerPath: '/static/', url: Uri.parse('dir/file.html'));

        expect(() => request.change(path: 'wrong'), throwsArgumentError);
      });

      test("throws if path isn't a path boundary", () {
        var uri = Uri.parse('https://test.example.com/static/dir/file.html');
        var request = new Request('GET', uri,
            handlerPath: '/static/', url: Uri.parse('dir/file.html'));

        expect(() => request.change(path: 'di'), throwsArgumentError);
      });
    });

    test("allows the original request to be read", () {
      var request = _request();
      var changed = request.change();

      expect(request.read().toList(), completion(isEmpty));
      expect(changed.read, throwsStateError);
    });

    test("allows the changed request to be read", () {
      var request = _request();
      var changed = request.change();

      expect(changed.read().toList(), completion(isEmpty));
      expect(request.read, throwsStateError);
    });

    test("allows another changed request to be read", () {
      var request = _request();
      var changed1 = request.change();
      var changed2 = request.change();

      expect(changed2.read().toList(), completion(isEmpty));
      expect(changed1.read, throwsStateError);
      expect(request.read, throwsStateError);
    });
  });
}
