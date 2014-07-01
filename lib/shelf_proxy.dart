library shelf_proxy;

import 'dart:io';

import 'package:shelf/shelf.dart';

///
///
/// Imagine that rootUri is specified as `http://example.com/files`
///
/// A request for `/test/sample.html` would result is a request for
/// `http://example.com/files/test/sample.html`.
Handler createProxyHandler(Uri rootUri) {
  if (rootUri.scheme != 'http' && rootUri.scheme != 'https') {
    throw new ArgumentError('rootUri must have a scheme of http or https.');
  }

  if (!rootUri.isAbsolute) {
    throw new ArgumentError('rootUri must be absolute.');
  }

  if (rootUri.query.isNotEmpty) {
    throw new ArgumentError('rootUri cannot contain a query.');
  }

  return (Request request) {
    // TODO: really need to tear down the client when this is done...
    var client = new HttpClient();

    var url = _getProxyUrl(rootUri, request.url);

    return client.openUrl(request.method, url).then((ioRequest) {
      return ioRequest.close();
    }).then((ioResponse) {
      var headers = {};
      // dart:io - HttpClientResponse.contentLength is -1 if not defined
      if (ioResponse.contentLength >= 0) {
        headers[HttpHeaders.CONTENT_LENGTH] =
            ioResponse.contentLength.toString();
      }

      return new Response(ioResponse.statusCode, body: ioResponse,
          headers: headers);
    });
  };
}

Uri _getProxyUrl(Uri proxyRoot, Uri requestUrl) {
  assert(proxyRoot.scheme == 'http' || proxyRoot.scheme == 'https');
  assert(proxyRoot.query == '');
  assert(proxyRoot.isAbsolute);
  assert(!requestUrl.isAbsolute);

  var updatedPath = proxyRoot.pathSegments.toList()
      ..addAll(requestUrl.pathSegments);

  return new Uri(scheme: proxyRoot.scheme,
      userInfo: proxyRoot.userInfo,
      host: proxyRoot.host,
      port: proxyRoot.port,
      pathSegments: updatedPath,
      query: requestUrl.query);
}
