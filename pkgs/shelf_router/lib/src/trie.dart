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

import 'router_entry.dart';

/// A simplified Trie node that stores routes matched by exact static path
/// segments.
final class _TrieNode {
  final staticChildren = <String, _TrieNode>{};

  /// Routes that fall back to RegExp matching at this level or below.
  /// For example, a route with parameters will be added to the [routes]
  /// of the deepest static node before the parameter.
  final routes = <RouterEntry>[];
}

/// A routing engine filter based on a Trie (prefix tree) data structure.
///
/// This provides O(L) candidate filtering complexity where L is the number
/// of segments in the path, quickly isolating the subset of routes that
/// share the exact static prefix for RegExp evaluation.
final class Trie {
  final _root = _TrieNode();
  int _nextIndex = 0;

  /// Adds a route to the trie based on its static prefix.
  void add(
    String verb,
    String route,
    Function handler, {
    Middleware? middleware,
  }) {
    final entry = RouterEntry(
      verb,
      route,
      handler,
      middleware: middleware,
      trieIndex: _nextIndex++,
    );
    var currentNode = _root;
    // Strip leading slash
    var path = entry.route;
    if (path.startsWith('/')) {
      path = path.substring(1);
    }

    // Completely truncate the route string at the very first parameter
    // variable `<`. Any static characters after the param are evaluated
    // exclusively by the RegExp fallback.
    final paramIndex = path.indexOf('<');
    if (paramIndex != -1) {
      path = path.substring(0, paramIndex);
    }

    // Split what's left into static segments.
    // If route was `/users/<id>`, we now just have `users/`.
    // If route was `/files/image_<id>.png`, we now have `files/image_`.
    final segments = path.split('/');

    // If the route contained a parameter, we don't traverse the last segment
    // as it's not fully static. This is achieved by taking all but the last
    // segment. This works correctly for both partial segments (e.g. `image_`
    // from `/files/image_<id>.png`) and for full segments that are just before
    // a parameter (e.g. the empty segment from `/users/<id>`).
    final segmentsToTraverse =
        (paramIndex != -1) ? segments.take(segments.length - 1) : segments;

    for (final segment in segmentsToTraverse) {
      currentNode =
          currentNode.staticChildren.putIfAbsent(segment, _TrieNode.new);
    }

    // Add the entry to the deepest FULLY static node we reached.
    currentNode.routes.add(entry);
  }

  /// Finds all Candidate routes for a given request path.
  /// It walks down the static prefix of the path, accumulating all
  /// routes that "stopped" at each level.
  List<RouterEntry> getCandidates(String path) {
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    final segments = path.split('/');
    var currentNode = _root;

    final candidatesSet = <RouterEntry>{...currentNode.routes};

    for (final segment in segments) {
      final nextNode = currentNode.staticChildren[segment];
      if (nextNode == null) {
        break;
      }
      currentNode = nextNode;
      candidatesSet.addAll(currentNode.routes);
    }

    // Evaluate trailing slashes: if a request is to `/users` (ending at the
    // `users` node), we must also include candidate routes registered
    // explicitly to `/users/` (which live in the `''` child node of `users`).
    // Conversely, if a request to `/users/` finishes walking the Trie, it
    // will naturally grab both `/users` and `/users/` during traversal.
    final trailingSlashNode = currentNode.staticChildren[''];
    if (trailingSlashNode != null) {
      candidatesSet.addAll(trailingSlashNode.routes);
    }

    // Preserve exact registration order to ensure routing priority is
    // maintained. By sorting only the candidates, we achieve O(K log K)
    // where K is the subset of matching routes, eliminating the O(N) list scan.
    return candidatesSet.toList(growable: false)
      ..sort((a, b) => a.trieIndex.compareTo(b.trieIndex));
  }
}
