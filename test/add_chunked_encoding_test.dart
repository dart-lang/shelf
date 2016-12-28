// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'test_util.dart';

void main() {
  test('adds chunked encoding with no transfer-encoding header', () async {
    var response = await _chunkResponse(
        new Response.ok(new Stream.fromIterable(["hi".codeUnits])));
    expect(response.headers, containsPair('transfer-encoding', 'chunked'));
    expect(response.readAsString(), completion(equals("2\r\nhi\r\n0\r\n\r\n")));
  });

  test('adds chunked encoding with transfer-encoding: identity', () async {
    var response = await _chunkResponse(new Response.ok(
        new Stream.fromIterable(["hi".codeUnits]),
        headers: {'transfer-encoding': 'identity'}));
    expect(response.headers, containsPair('transfer-encoding', 'chunked'));
    expect(response.readAsString(), completion(equals("2\r\nhi\r\n0\r\n\r\n")));
  });

  test("doesn't add chunked encoding with content length", () async {
    var response = await _chunkResponse(new Response.ok("hi"));
    expect(response.headers, isNot(contains('transfer-encoding')));
    expect(response.readAsString(), completion(equals("hi")));
  });

  test("doesn't add chunked encoding with status 1xx", () async {
    var response = await _chunkResponse(
        new Response(123, body: new Stream.empty()));
    expect(response.headers, isNot(contains('transfer-encoding')));
    expect(response.read().toList(), completion(isEmpty));
  });

  test("doesn't add chunked encoding with status 204", () async {
    var response = await _chunkResponse(
        new Response(204, body: new Stream.empty()));
    expect(response.headers, isNot(contains('transfer-encoding')));
    expect(response.read().toList(), completion(isEmpty));
  });

  test("doesn't add chunked encoding with status 304", () async {
    var response = await _chunkResponse(
        new Response(204, body: new Stream.empty()));
    expect(response.headers, isNot(contains('transfer-encoding')));
    expect(response.read().toList(), completion(isEmpty));
  });

  test("doesn't add chunked encoding with status 204", () async {
    var response = await _chunkResponse(
        new Response(204, body: new Stream.empty()));
    expect(response.headers, isNot(contains('transfer-encoding')));
    expect(response.read().toList(), completion(isEmpty));
  });

  test("doesn't add chunked encoding with status 204", () async {
    var response = await _chunkResponse(
        new Response(204, body: new Stream.empty()));
    expect(response.headers, isNot(contains('transfer-encoding')));
    expect(response.read().toList(), completion(isEmpty));
  });
}

Future<Response> _chunkResponse(Response response) =>
    addChunkedEncoding((_) => response)(null);
