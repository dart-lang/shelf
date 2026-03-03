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

import '../shelf_router.dart';

/// Represents a single part of a route pattern in the [TrieRouter].
///
/// The Trie handles static segments and parameterized segments (:id or <id>).
class TrieNode {
  /// Maps exact string matches to the next node.
  final Map<String, TrieNode> staticChildren = {};

  /// The child node for any parameterized segment at this level.
  TrieNode? paramChild;

  /// The name of the parameter if this node represents a parameterized segment.
  String? paramName;

  /// Handlers registered at this node, mapped by HTTP verb
  /// (e.g., 'GET', 'POST', 'ALL').
  ///
  /// Used if this node is the leaf of a route.
  final Map<String, VerbHandler> verbHandlers = {};

  /// Whether any handlers are registered at this node.
  bool get isLeaf => verbHandlers.isNotEmpty;
}

/// A wrapper for a handler with its associated metadata in the [TrieRouter].
class VerbHandler {
  /// The shelf handler (can be a standard [Handler] or a function with
  /// positional parameters).
  final Function handler;

  /// Middleware specific to this route.
  final Middleware? middleware;

  /// The original route pattern for debugging and identification.
  final String route;

  /// Optional callback to dump the tree of a nested
  /// router, used for [Router.inspectTree].
  final String Function(String indent)? childDump;

  VerbHandler(this.handler, this.middleware, this.route, {this.childDump});
}

/// A routing engine based on a Trie (prefix tree) data structure.
///
/// This provides O(L) lookup complexity where L is the number of segments in
/// the path, regardless of the total number of routes.
class TrieRouter {
  /// The root node of the trie.
  final TrieNode root = TrieNode();

  /// Adds a route to the trie.
  ///
  /// [verb] is the HTTP method (or 'ALL').
  /// [route] is the path pattern.
  /// [handler] is the shelf handler.
  /// [middleware] is optional middleware for this route.
  /// [childDump] is an optional callback to describe nested routers.
  void addRoute(
    String verb,
    String route,
    Function handler,
    Middleware? middleware, {
    String Function(String indent)? childDump,
  }) {
    var currentNode = root;
    // Strip leading slash, keep trailing
    var cleanRoute = route;
    if (cleanRoute.startsWith('/')) {
      cleanRoute = cleanRoute.substring(1);
    }

    // Simplest approach: split by `/`.
    final segments = cleanRoute.split('/');

    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];

      // Handle old <param> syntax
      if (segment.startsWith('<') && segment.endsWith('>')) {
        var inner = segment.substring(1, segment.length - 1);
        var parts = inner.split('|');
        var name = parts.first;

        if (parts.length > 1) {
          print('Warning: Regex in "$segment" is no longer supported '
              'and will be ignored for performance.');
        }
        print('Warning: The <param> syntax in "$route" is '
            'deprecated. Use ":$name" instead.');

        // Handle catch-all parameter (often used in mount)
        if (segment.contains('|[^]*>')) {
          name = '*$name'; // Special marker
        }
        // Handle fallback catch-all <*>, <_>, <_|[...]> etc
        else if (segment == '<*>') {
          name = '**'; // Strips to '*'
        } else if (segment.startsWith('<_')) {
          name = '*_'; // Strips to '_'
        }

        if (currentNode.paramChild == null) {
          currentNode.paramChild = TrieNode()..paramName = name;
        } else if (currentNode.paramChild!.paramName != name) {
          throw Exception('Conflicting parameter names at the'
              ' same level in route "$route"');
        }
        currentNode = currentNode.paramChild!;
      }
      // Handle new :param syntax
      else if (segment.startsWith(':')) {
        final name = segment.substring(1);
        if (currentNode.paramChild == null) {
          currentNode.paramChild = TrieNode()..paramName = name;
        } else if (currentNode.paramChild!.paramName != name) {
          throw Exception('Conflicting parameter names at the same'
              ' level in route "$route"');
        }
        currentNode = currentNode.paramChild!;
      }
      // Static segment
      else {
        currentNode.staticChildren.putIfAbsent(segment, TrieNode.new);
        currentNode = currentNode.staticChildren[segment]!;
      }
    }

    // Register handler at the leaf
    currentNode.verbHandlers[verb] =
        VerbHandler(handler, middleware, route, childDump: childDump);
  }

  /// Returns a tree-like string representation of the route trie.
  String inspectTree({String indent = ''}) {
    final sb = StringBuffer();
    if (indent.isEmpty) sb.write('.\n');
    _dump(root, sb, indent);
    return sb.toString().trimRight();
  }

  void _dump(TrieNode node, StringBuffer sb, String indent) {
    final hasChildDump =
        node.verbHandlers.values.any((h) => h.childDump != null);

    final staticEntries = node.staticChildren.entries.toList();
    final hasParam = node.paramChild != null;

    final filteredStatic = <MapEntry<String, TrieNode>>[];
    if (!hasChildDump) {
      for (final entry in staticEntries) {
        if (entry.key.isNotEmpty) {
          filteredStatic.addAll([entry]);
        }
      }
    }

    final showParam = hasParam && !hasChildDump;
    final total = filteredStatic.length + (showParam ? 1 : 0);

    for (var i = 0; i < total; i++) {
      final isLast = i == total - 1;
      final connector = isLast ? '└── ' : '├── ';
      final nextIndent = indent + (isLast ? '    ' : '│   ');

      if (i < filteredStatic.length) {
        final entry = filteredStatic[i];
        var label = entry.key;

        // Merging trailing slash?
        final slashChild = entry.value.staticChildren[''];
        bool canMerge = slashChild != null &&
            slashChild.staticChildren.isEmpty &&
            slashChild.paramChild == null;

        if (canMerge) {
          label = '$label [/]';
        }

        sb.write('$indent$connector$label');
        _appendHandlers(entry.value, sb, nextIndent,
            slashNode: canMerge ? slashChild : null);
        sb.writeln();

        // If we merged, we skip the staticChild[''] in recursive dump
        if (canMerge) {
          // We'll create a proxy node to avoid dumping the slashChild again
          final proxy = TrieNode();
          entry.value.staticChildren.forEach((k, v) {
            if (k.isNotEmpty) proxy.staticChildren[k] = v;
          });
          proxy.paramChild = entry.value.paramChild;
          _dump(proxy, sb, nextIndent);
        } else {
          _dump(entry.value, sb, nextIndent);
        }
      } else {
        final paramNode = node.paramChild!;
        final name =
            paramNode.paramName != null && paramNode.paramName!.startsWith('*')
                ? ':*${paramNode.paramName!.substring(1)}'
                : ':${paramNode.paramName}';
        sb.write('$indent$connector$name');
        _appendHandlers(paramNode, sb, nextIndent);
        sb.writeln();
        _dump(paramNode, sb, nextIndent);
      }
    }
  }

  void _appendHandlers(TrieNode node, StringBuffer sb, String indent,
      {TrieNode? slashNode}) {
    final merged = Map<String, VerbHandler>.from(node.verbHandlers);
    if (slashNode != null) {
      slashNode.verbHandlers.forEach((verb, handler) {
        merged.putIfAbsent(verb, () => handler);
      });
    }

    if (merged.isNotEmpty) {
      final verbs = merged.keys.join(', ');
      sb.write(' ($verbs)');

      for (final handler in merged.values) {
        if (handler.childDump != null) {
          final child = handler.childDump!(indent);
          if (child.isNotEmpty) {
            sb.write('\n${child.trimRight()}');
          }
          break;
        }
      }
    }
  }

  /// Finds all matching routes, yields them in order of priority (specificity).
  Iterable<MatchResult> findAllMatches(String method, String path) {
    var cleanPath = path;
    if (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }

    final segments = cleanPath.split('/').map(Uri.decodeComponent).toList();
    return _walk(root, segments, 0, {}, method, 0);
  }

  Iterable<MatchResult> _walk(
      TrieNode node,
      List<String> segments,
      int segmentIndex,
      Map<String, String> params,
      String method,
      int hops) sync* {
    // If we reached the end of the path...
    if (segmentIndex >= segments.length) {
      final handlerInfo = node.verbHandlers[method] ?? node.verbHandlers['ALL'];
      if (handlerInfo != null) {
        yield MatchResult(handlerInfo, Map.of(params), hops);
      }

      // If it's a catch-all param that's empty
      if (node.paramChild != null &&
          node.paramChild!.paramName!.startsWith('*')) {
        final paramName = node.paramChild!.paramName!.substring(1);
        params[paramName] = '';
        final handlerInfo = node.paramChild!.verbHandlers[method] ??
            node.paramChild!.verbHandlers['ALL'];
        if (handlerInfo != null) {
          yield MatchResult(handlerInfo, Map.of(params), hops + 1);
        }
        params.remove(paramName);
      }
      return;
    }

    final segment = segments[segmentIndex];

    // Priority 1: Exact static match
    final staticChild = node.staticChildren[segment];
    if (staticChild != null) {
      yield* _walk(
          staticChild, segments, segmentIndex + 1, params, method, hops + 1);
    }

    // Priority 2: Param match
    if (node.paramChild != null) {
      final paramName = node.paramChild!.paramName!;

      if (paramName.startsWith('*')) {
        final realName = paramName.substring(1);
        params[realName] = segments.sublist(segmentIndex).join('/');

        final handlerInfo = node.paramChild!.verbHandlers[method] ??
            node.paramChild!.verbHandlers['ALL'];
        if (handlerInfo != null) {
          yield MatchResult(handlerInfo, Map.of(params), hops + 1);
        }
        params.remove(realName);
      } else {
        params[paramName] = segment;
        yield* _walk(node.paramChild!, segments, segmentIndex + 1, params,
            method, hops + 1);
        params.remove(paramName);
      }
    }

    // Priority 3: Fallback for prefixes (supporting mount)
    final fallbackHandler =
        node.verbHandlers[method] ?? node.verbHandlers['ALL'];
    if (fallbackHandler != null &&
        (fallbackHandler.route.endsWith('/') ||
            fallbackHandler.route.endsWith('[^]*>'))) {
      yield MatchResult(fallbackHandler, Map.of(params), hops);
    }
  }
}

/// Represents the result of a successful match in the [TrieRouter].
class MatchResult {
  /// The handler and metadata associated with the matched route.
  final VerbHandler handlerInfo;

  /// Parameters extracted from the path segments.
  final Map<String, String> params;

  /// The number of trie nodes (hops) traversed to find this match.
  final int hops;

  MatchResult(this.handlerInfo, this.params, this.hops);
}
