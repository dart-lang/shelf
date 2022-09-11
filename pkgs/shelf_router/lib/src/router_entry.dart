// Copyright 2019 Google LLC
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

/// Check if the [regexp] is non-capturing.
bool _isNoCapture(String regexp) {
  // Construct a new regular expression matching anything containing regexp,
  // then match with empty-string and count number of groups.
  return RegExp('^(?:$regexp)|.*\$').firstMatch('')!.groupCount == 0;
}

/// Entry in the router.
///
/// This class implements the logic for matching the path pattern.
class RouterEntry {
  /// Pattern for parsing the route pattern
  static final RegExp _parser = RegExp(r'([^<]*)(?:<([^>|]+)(?:\|([^>]*))?>)?');

  final String verb, route;
  final Function _handler;
  final Middleware _middleware;

  /// This router entry is used
  /// as a mount point
  final bool _mounted;

  /// Expression that the request path must match.
  ///
  /// This also captures any parameters in the route pattern.
  final RegExp _routePattern;

  /// Names for the parameters in the route pattern.
  final List<ParamInfo> _paramInfos;

  List<ParamInfo> get paramInfos => _paramInfos.toList();

  /// List of parameter names in the route pattern.
  // exposed for using generator.
  List<String> get params => _paramInfos.map((p) => p.name).toList();

  RouterEntry._(this.verb, this.route, this._handler, this._middleware,
      this._routePattern, this._paramInfos, this._mounted);

  factory RouterEntry(
    String verb,
    String route,
    Function handler, {
    Middleware? middleware,
    bool mounted = false,
  }) {
    middleware = middleware ?? ((Handler fn) => fn);

    if (!route.startsWith('/')) {
      throw ArgumentError.value(
          route, 'route', 'expected route to start with a slash');
    }

    final params = <ParamInfo>[];
    var pattern = '';
    // Keep the index where the matches are located
    // so that we can calculate the positioning of
    // the extracted parameter
    var prevMatchIndex = 0;
    for (var m in _parser.allMatches(route)) {
      final firstGroup = m[1]!;
      pattern += RegExp.escape(firstGroup);
      if (m[2] != null) {
        final paramName = m[2]!;
        final startIdx = prevMatchIndex + firstGroup.length;
        final paramInfo = ParamInfo(
          name: paramName,
          startIdx: startIdx,
          endIdx: m.end,
        );
        params.add(paramInfo);
        prevMatchIndex = m.end;

        if (m[3] != null && !_isNoCapture(m[3]!)) {
          throw ArgumentError.value(
              route, 'route', 'expression for "${m[2]}" is capturing');
        }
        pattern += '(${m[3] ?? r'[^/]+'})';
      }
    }
    final routePattern = RegExp('^$pattern\$');

    return RouterEntry._(
        verb, route, handler, middleware, routePattern, params, mounted);
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
    for (var i = 0; i < _paramInfos.length; i++) {
      // first group is always the full match, we ignore this group.
      final paramInfo = _paramInfos[i];
      params[paramInfo.name] = m[i + 1]!;
    }
    return params;
  }

  // invoke handler with given request and params
  Future<Response> invoke(Request request, Map<String, String> params) async {
    request = request.change(context: {'shelf_router/params': params});

    return await _middleware((request) async {
      if (_mounted) {
        // if this route is mounted, we include
        // the route itself as a parameter so
        // that the mount can extract the parameters
        return await _handler(request, this) as Response;
      }

      if (_handler is Handler || _paramInfos.isEmpty) {
        return await _handler(request) as Response;
      }

      return await Function.apply(_handler, [
        request,
        ..._paramInfos.map((info) => params[info.name]),
      ]) as Response;
    })(request);
  }
}

/// This class holds information about a parameter extracted
/// from the route path.
/// The indexes can by used by the mount logic to resolve the
/// parametrized path when handling the request.
class ParamInfo {
  /// This is the name of the parameter, without <, >
  final String name;

  /// The index in the route String where the parameter
  /// expression starts (inclusive)
  final int startIdx;

  /// The index in the route String where the parameter
  /// expression ends (exclusive)
  final int endIdx;

  const ParamInfo({
    required this.name,
    required this.startIdx,
    required this.endIdx,
  });
}
