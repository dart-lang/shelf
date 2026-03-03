// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:shelf/shelf.dart';

import '../../shelf_router.dart';

/// Middleware that removes trailing slashes from the request URL path.
///
/// This allows the [Router] to match paths like `/hello/` against a route
/// defined as `/hello`.
///
/// Note: This only affects the [Request.url.path], which is what the
/// [Router] matches against. It does not modify [Request.requestedUri].
Middleware removeTrailingSlash() => (Handler innerHandler) {
      return (Request request) {
        var path = request.url.path;
        if (path.length > 1 && path.endsWith('/')) {
          final newPath = path.substring(0, path.length - 1);

          // We use change(path: ...) which updates both handlerPath and url
          // correctly for nested routers, but here we just want to normalize
          // the trailing slash for the CURRENT router.
          // However, Request.url.path is relative to handlerPath.
          // If we want to strip the trailing slash from the path the router
          // sees, we should update the request URL.

          // To keep Request invariants, we must adjust requestedUri as well.
          final newRequestedUriPath = request.requestedUri.path
              .substring(0, request.requestedUri.path.length - 1);
          final newRequestedUri =
              request.requestedUri.replace(path: newRequestedUriPath);

          // Create a new request with the normalized path.
          // Note: we use request.read() which is safe as long as the body
          // hasn't been read yet or is a type that can be read multiple times
          // (like String or List<int>).
          request = Request(
            request.method,
            newRequestedUri,
            protocolVersion: request.protocolVersion,
            headers: request.headersAll,
            handlerPath: request.handlerPath,
            url: request.url.replace(path: newPath),
            body: request.read(),
            context: request.context,
            onHijack: (callback) => request.hijack(callback),
          );
        }
        return innerHandler(request);
      };
    };
