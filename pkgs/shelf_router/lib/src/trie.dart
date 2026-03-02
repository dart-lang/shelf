import 'package:shelf/shelf.dart';

/// Represents a single part of a route pattern.
/// The Trie handles static segments and parameterized segments (:id).
class TrieNode {
  /// Maps exact string matches to the next node.
  final Map<String, TrieNode> staticChildren = {};

  /// The child node for any parameterized segment.
  TrieNode? paramChild;

  /// The name of the parameter if this node represents a parameterized segment.
  String? paramName;

  /// Handlers registered at this node, mapped by HTTP verb.
  /// Used if this node is the leaf of a route.
  final Map<String, VerbHandler> verbHandlers = {};

  bool get isLeaf => verbHandlers.isNotEmpty;
}

class VerbHandler {
  final Function handler;
  final Middleware? middleware;
  final String route; // Original route pattern for debugging

  VerbHandler(this.handler, this.middleware, this.route);
}

class TrieRouter {
  final TrieNode root = TrieNode();

  void addRoute(
    String verb,
    String route,
    Function handler,
    Middleware? middleware,
  ) {
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
        print(
            'Warning: The <param> syntax in "$route" is deprecated. Use ":param" instead.');

        var inner = segment.substring(1, segment.length - 1);
        var name = inner.split('|').first;

        // Handle catch-all parameter (often used in mount)
        if (segment.contains('|[^]*>')) {
          name = '*$name'; // Special marker
        }
        // Handle fallback catch-all <*>, <_>, <_|[...]> etc
        else if (segment == '<*>' || segment.startsWith('<_')) {
          name = '*catchAll';
        }

        if (currentNode.paramChild == null) {
          currentNode.paramChild = TrieNode()..paramName = name;
        } else if (currentNode.paramChild!.paramName != name) {
          throw Exception(
              'Conflicting parameter names at the same level in route "$route"');
        }
        currentNode = currentNode.paramChild!;
      }
      // Handle new :param syntax
      else if (segment.startsWith(':')) {
        final name = segment.substring(1);
        if (currentNode.paramChild == null) {
          currentNode.paramChild = TrieNode()..paramName = name;
        } else if (currentNode.paramChild!.paramName != name) {
          throw Exception(
              'Conflicting parameter names at the same level in route "$route"');
        }
        currentNode = currentNode.paramChild!;
      }
      // Static segment
      else {
        currentNode.staticChildren.putIfAbsent(segment, () => TrieNode());
        currentNode = currentNode.staticChildren[segment]!;
      }
    }

    // Register handler at the leaf
    currentNode.verbHandlers[verb] = VerbHandler(handler, middleware, route);
  }

  /// Finds all matching routes, yields them in order of priority (specificity).
  Iterable<MatchResult> findAllMatches(String method, String path) {
    var cleanPath = path;
    if (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }

    final segments = cleanPath.split('/').map(Uri.decodeComponent).toList();
    return _walk(root, segments, 0, {}, method);
  }

  Iterable<MatchResult> _walk(TrieNode node, List<String> segments,
      int segmentIndex, Map<String, String> params, String method) sync* {
    // If we reached the end of the path...
    if (segmentIndex >= segments.length) {
      final handlerInfo = node.verbHandlers[method] ?? node.verbHandlers['ALL'];
      if (handlerInfo != null) {
        yield MatchResult(handlerInfo, Map.of(params));
      }

      // If it's a catch-all param that's empty
      if (node.paramChild != null &&
          node.paramChild!.paramName!.startsWith('*')) {
        final paramName = node.paramChild!.paramName!.substring(1);
        params[paramName] = '';
        final handlerInfo = node.paramChild!.verbHandlers[method] ??
            node.paramChild!.verbHandlers['ALL'];
        if (handlerInfo != null) {
          yield MatchResult(handlerInfo, Map.of(params));
        }
        params.remove(paramName);
      }
      return;
    }

    final segment = segments[segmentIndex];

    // Priority 1: Exact static match
    final staticChild = node.staticChildren[segment];
    if (staticChild != null) {
      yield* _walk(staticChild, segments, segmentIndex + 1, params, method);
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
          yield MatchResult(handlerInfo, Map.of(params));
        }
        params.remove(realName);
      } else {
        params[paramName] = segment;
        yield* _walk(
            node.paramChild!, segments, segmentIndex + 1, params, method);
        params.remove(paramName);
      }
    }

    // Priority 3: Fallback for prefixes (supporting mount)
    final fallbackHandler =
        node.verbHandlers[method] ?? node.verbHandlers['ALL'];
    if (fallbackHandler != null &&
        (fallbackHandler.route.endsWith('/') ||
            fallbackHandler.route.endsWith('[^]*>'))) {
      yield MatchResult(fallbackHandler, Map.of(params));
    }
  }
}

class MatchResult {
  final VerbHandler handlerInfo;
  final Map<String, String> params;

  MatchResult(this.handlerInfo, this.params);
}
