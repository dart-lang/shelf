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

import 'dart:async';

import 'package:shelf/shelf.dart';

import '../shelf_router.dart';

/// Entry in the router.
///
/// This class was originally used for all routing and is now primarily used
/// by [Router.call] to handle the invocation of handlers with dynamic arguments
/// (parameter binding) and middleware.
class RouterEntry {
  /// The HTTP verb this entry matches.
  final String verb;

  /// The original route pattern.
  final String route;

  final Function _handler;
  final Middleware _middleware;

  /// Expression that the request path must match.
  ///
  /// This also captures any parameters in the route pattern.
  final RegExp _routePattern;

  /// Names for the parameters in the route pattern.
  final List<String> _params;

  /// List of parameter names in the route pattern.
  List<String> get params => _params.toList(); // exposed for using generator.

  RouterEntry._(this.verb, this.route, this._handler, this._middleware,
      this._routePattern, this._params);

  factory RouterEntry(
    String verb,
    String route,
    Function handler, {
    Middleware? middleware,
  }) {
    middleware = middleware ?? ((Handler fn) => fn);

    if (!route.startsWith('/')) {
      throw ArgumentError.value(
          route, 'route', 'expected route to start with a slash');
    }

    final params = <String>[];
    var pattern = '';

    // Split route by segments to handle both :param and <param>
    final segments = route.substring(1).split('/');
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      pattern += '/';

      if (segment.startsWith(':')) {
        final name = segment.substring(1);
        params.add(name.startsWith('*') ? name.substring(1) : name);
        if (name.startsWith('*')) {
          pattern += '(.*)';
        } else {
          pattern += '([^/]+)';
        }
      } else if (segment.startsWith('<') && segment.endsWith('>')) {
        final inner = segment.substring(1, segment.length - 1);
        final parts = inner.split('|');
        final name = parts[0];
        final expr = parts.length > 1 ? parts[1] : null;

        if (expr == '[^]*' ||
            expr == '.*' ||
            segment == '<*>' ||
            segment.startsWith('<_')) {
          // catch-all special case
          params.add(name);
          pattern += '(.*)';
        } else {
          // Ignore regex for performance as requested.
          params.add(name);
          pattern += '([^/]+)';
        }
      } else {
        pattern += RegExp.escape(segment);
      }
    }

    final routePattern = RegExp('^$pattern\$');

    return RouterEntry._(
        verb, route, handler, middleware, routePattern, params);
  }

  /// Returns a map from parameter name to value, if the path matches the
  /// route pattern. Otherwise returns null.
  Map<String, String>? match(String path) {
    // Check if path matches the route pattern
    var m = _routePattern.firstMatch(path);
    if (m == null) {
      return null;
    }
    // Construct map from parameter name to matched value
    var params = <String, String>{};
    for (var i = 0; i < _params.length; i++) {
      // first group is always the full match, we ignore this group.
      params[_params[i]] = m[i + 1]!;
    }
    return params;
  }

  /// Invokes the handler associated with this entry.
  ///
  /// This handles parameter binding, applying middleware, and converting
  /// the result to a [Future<Response>].
  Future<Response> invoke(Request request, Map<String, String> params) async {
    request = request.change(context: {'shelf_router/params': params});

    return await _middleware((request) async {
      if (_handler is Handler || _params.isEmpty) {
        // ignore: avoid_dynamic_calls
        return await _handler(request) as Response;
      }
      return await Function.apply(_handler, [
        request,
        ..._params.map((n) => params[n]),
      ]) as Response;
    })(request);
  }
}
