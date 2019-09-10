## Web Server Middleware for Dart

[![Build Status](https://travis-ci.org/dart-lang/shelf.svg?branch=master)](https://travis-ci.org/dart-lang/shelf)
[![Coverage Status](https://coveralls.io/repos/dart-lang/shelf/badge.svg?branch=master)](https://coveralls.io/r/dart-lang/shelf)

## Introduction

**Shelf** makes it easy to create and compose **web servers** and **parts of web
servers**. How?

* Expose a small set of simple types.
* Map server logic into a simple function: a single argument for the request,
the response is the return value.
* Trivially mix and match synchronous and asynchronous processing.
* Flexibility to return a simple string or a byte stream with the same model.

## Example

See `example/example.dart`

```dart
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;

void main() {
  var handler = const shelf.Pipeline().addMiddleware(shelf.logRequests())
      .addHandler(_echoRequest);

  io.serve(handler, 'localhost', 8080).then((server) {
    print('Serving at http://${server.address.host}:${server.port}');
  });
}

shelf.Response _echoRequest(shelf.Request request) {
  return new shelf.Response.ok('Request for "${request.url}"');
}
```

## Handlers and Middleware

A [handler][] is any function that handles a [shelf.Request][] and returns a
[shelf.Response][]. It can either handle the request itself--for example, a
static file server that looks up the requested URI on the filesystem--or it can
do some processing and forward it to another handler--for example, a logger that
prints information about requests and responses to the command line.

[handler]: https://pub.dev/documentation/shelf/latest/shelf/Handler.html

[shelf.Request]: https://pub.dev/documentation/shelf/latest/shelf/Request-class.html

[shelf.Response]: https://pub.dev/documentation/shelf/latest/shelf/Response-class.html

The latter kind of handler is called "[middleware][]", since it sits in the
middle of the server stack. Middleware can be thought of as a function that
takes a handler and wraps it in another handler to provide additional
functionality. A Shelf application is usually composed of many layers of
middleware with one or more handlers at the very center; the [shelf.Pipeline][]
class makes this sort of application easy to construct.

[middleware]: https://pub.dev/documentation/shelf/latest/shelf/Middleware.html

[shelf.Pipeline]: https://pub.dev/documentation/shelf/latest/shelf/Pipeline-class.html

Some middleware can also take multiple handlers and call one or more of them for
each request. For example, a routing middleware might choose which handler to
call based on the request's URI or HTTP method, while a cascading middleware
might call each one in sequence until one returns a successful response.

Middleware that routes requests between handlers should be sure to update each
request's [`handlerPath`][handlerPath] and [`url`][url]. This allows inner
handlers to know where they are in the application so they can do their own
routing correctly. This can be easily accomplished using
[`Request.change()`][change]:

[handlerPath]: https://pub.dev/documentation/shelf/latest/shelf/Request/handlerPath.html
[url]: https://pub.dev/documentation/shelf/latest/shelf/Request/url.html
[change]: https://pub.dev/documentation/shelf/latest/shelf/Request/change.html

```dart
// In an imaginary routing middleware...
var component = request.url.pathComponents.first;
var handler = _handlers[component];
if (handler == null) return new Response.notFound(null);

// Create a new request just like this one but with whatever URL comes after
// [component] instead.
return handler(request.change(script: component));
```

## Adapters

An adapter is any code that creates [shelf.Request][] objects, passes them to a
handler, and deals with the resulting [shelf.Response][]. For the most part,
adapters forward requests from and responses to an underlying HTTP server;
[shelf_io.serve][] is this sort of adapter. An adapter might also synthesize
HTTP requests within the browser using `window.location` and `window.history`,
or it might pipe requests directly from an HTTP client to a Shelf handler.

[shelf_io.serve]: https://pub.dev/documentation/shelf/latest/shelf_io/serve.html

### API Requirements

An adapter must handle all errors from the handler, including the handler
returning a `null` response. It should print each error to the console if
possible, then act as though the handler returned a 500 response. The adapter
may include body data for the 500 response, but this body data must not include
information about the error that occurred. This ensures that unexpected errors
don't result in exposing internal information in production by default; if the
user wants to return detailed error descriptions, they should explicitly include
middleware to do so.

An adapter should ensure that asynchronous errors thrown by the handler don't
cause the application to crash, even if they aren't reported by the future
chain. Specifically, these errors shouldn't be passed to the root zone's error
handler; however, if the adapter is run within another error zone, it should
allow these errors to be passed to that zone. The following function can be used
to capture only errors that would otherwise be top-leveled:

```dart
/// Run [callback] and capture any errors that would otherwise be top-leveled.
///
/// If [this] is called in a non-root error zone, it will just run [callback]
/// and return the result. Otherwise, it will capture any errors using
/// [runZoned] and pass them to [onError].
catchTopLevelErrors(callback(), void onError(error, StackTrace stackTrace)) {
  if (Zone.current.inSameErrorZone(Zone.ROOT)) {
    return runZoned(callback, onError: onError);
  } else {
    return callback();
  }
}
```

An adapter that knows its own URL should provide an implementation of the
[`Server`][server] interface.

[server]: https://pub.dev/documentation/shelf/latest/shelf/Server-class.html

### Request Requirements

When implementing an adapter, some rules must be followed. The adapter must not
pass the `url` or `handlerPath` parameters to [new shelf.Request][]; it should
only pass `requestedUri`. If it passes the `context` parameter, all keys must
begin with the adapter's package name followed by a period. If multiple headers
with the same name are received, the adapter must collapse them into a single
header separated by commas as per [RFC 2616 section 4.2][].

[new shelf.Request]: https://pub.dev/documentation/shelf/latest/shelf/Request/Request.html

[RFC 2616 section 4.2]: http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html

If the underlying request uses a chunked transfer coding, the adapter must
decode the body before passing it to [new shelf.Request][] and should remove the
`Transfer-Encoding` header. This ensures that message bodies are chunked if and
only if the headers declare that they are.

### Response Requirements

An adapter must not add or modify any [entity headers][] for a response.

[entity headers]: https://www.w3.org/Protocols/rfc2616/rfc2616-sec7.html#sec7.1

If *none* of the following conditions are true, the adapter must apply
[chunked transfer coding][] to a response's body and set its Transfer-Encoding header to `chunked`:

* The status code is less than 200, or equal to 204 or 304.
* A Content-Length header is provided.
* The Content-Type header indicates the MIME type `multipart/byteranges`.
* The Transfer-Encoding header is set to anything other than `identity`.

[chunked transfer coding]: https://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.6.1

Adapters may find the [`addChunkedEncoding()`][addChunkedEncoding] middleware
useful for implementing this behavior, if the underlying server doesn't
implement it manually.

When responding to a HEAD request, the adapter must not emit an entity body.
Otherwise, it shouldn't modify the entity body in any way.

An adapter should include information about itself in the Server header of the
response by default. If the handler returns a response with the Server header
set, that must take precedence over the adapter's default header.

An adapter should include the Date header with the time the handler returns a
response. If the handler returns a response with the Date header set, that must
take precedence.

## Inspiration

* [Connect](http://www.senchalabs.org/connect/) for NodeJS.
    * Read [this great write-up](http://howtonode.org/connect-it) to understand
      the overall philosophy of all of these models.
* [Rack](http://rack.github.io/) for Ruby.
* [WSGI](http://legacy.python.org/dev/peps/pep-3333/) for Python.
