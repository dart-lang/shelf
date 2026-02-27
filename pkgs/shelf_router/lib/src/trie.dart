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
    // Example: `users/123/edit` -> ['users', '123', 'edit']
    // Example: `users/` -> ['users', '']
    final segments = cleanRoute.split('/');

    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];

      // Handle old <param> syntax
      if (segment.startsWith('<') && segment.endsWith('>')) {
        print('Warning: The <param> syntax in "$route" is deprecated. Use ":param" instead.');
        
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
          throw Exception('Conflicting parameter names at the same level in route "$route"');
        }
        currentNode = currentNode.paramChild!;
      }
      // Handle new :param syntax
      else if (segment.startsWith(':')) {
        final name = segment.substring(1);
        if (currentNode.paramChild == null) {
          currentNode.paramChild = TrieNode()..paramName = name;
        } else if (currentNode.paramChild!.paramName != name) {
          throw Exception('Conflicting parameter names at the same level in route "$route"');
        }
        currentNode = currentNode.paramChild!;
      }
      // Handle fallback catch-all <_|[^]*> or custom names without < > wrap if any
      else if (segment.contains('|[^]*>')) {
        final name = '*_' + segment;
        if (currentNode.paramChild == null) {
          currentNode.paramChild = TrieNode()..paramName = name;
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

  /// Finds a matching route and extracts parameters.
  MatchResult? match(String method, String path) {
    var cleanPath = path;
    if (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }
    
    final segments = cleanPath.split('/');
    final params = <String, String>{};

    return _walk(root, segments, 0, params, method);
  }

  MatchResult? _walk(TrieNode node, List<String> segments, int segmentIndex, Map<String, String> params, String method) {
    // If we reached the end of the path...
    if (segmentIndex >= segments.length) {
      // Does this node have a handler for the given method?
      final handlerInfo = node.verbHandlers[method] ?? node.verbHandlers['ALL'];
      if (handlerInfo != null) {
        return MatchResult(handlerInfo, Map.of(params));
      }
      
      // If it's a catch-all param that's empty
      if (node.paramChild != null && node.paramChild!.paramName!.startsWith('*')) {
          final paramName = node.paramChild!.paramName!.substring(1);
          params[paramName] = '';
          final handlerInfo = node.paramChild!.verbHandlers[method] ?? node.paramChild!.verbHandlers['ALL'];
          if (handlerInfo != null) {
            return MatchResult(handlerInfo, Map.of(params));
          }
          params.remove(paramName);
      }
      
      return null;
    }

    final segment = segments[segmentIndex];

    // Priority 1: Exact static match
    final staticChild = node.staticChildren[segment];
    if (staticChild != null) {
      final result = _walk(staticChild, segments, segmentIndex + 1, params, method);
      if (result != null) return result;
    }

    // Priority 2: Param match
    if (node.paramChild != null) {
      final paramName = node.paramChild!.paramName!;
      
      // If it's a catch-all param, it consumes the rest of the segments
      if (paramName.startsWith('*')) {
         final realName = paramName.substring(1);
         params[realName] = segments.sublist(segmentIndex).join('/');
         
         // Catch-alls are always leaf handlers for the segments they consume
         final handlerInfo = node.paramChild!.verbHandlers[method] ?? node.paramChild!.verbHandlers['ALL'];
         if (handlerInfo != null) {
             return MatchResult(handlerInfo, Map.of(params));
         }
         // If no handler, backtrack
         params.remove(realName);
         
         // Try matching sub-patterns inside nested routers if mounted
         final fallbackParams = Map<String, String>.from(params);
         fallbackParams[realName] = segment;
         final fallbackResult = _walk(node.paramChild!, segments, segmentIndex + 1, fallbackParams, method);
         if (fallbackResult != null) return fallbackResult;
      } else {
         params[paramName] = segment;
         final result = _walk(node.paramChild!, segments, segmentIndex + 1, params, method);
         if (result != null) return result;
         // Backtrack
         params.remove(paramName);
      }
    }

    // Priority 3: If this segment is empty and the current node has a handler, match it.
    // This happens for trailing slashes matching the exact route, or a mounted router.
    if (segment.isEmpty && segmentIndex == segments.length - 1) {
       final handlerInfo = node.verbHandlers[method] ?? node.verbHandlers['ALL'];
       if (handlerInfo != null) {
         return MatchResult(handlerInfo, Map.of(params));
       }
    }
    
    // Priority 4: Fallback for mount routers. If we're midway through a path and this node
    // is a leaf (like a mounted Router), it should handle the rest of the path if no deeper match is found.
    // NOTE: In shelf_router, `app.mount('/api', router)` actually adds two routes:
    // `/api` and `/api/<path|[^]*>`. We should rely on the catch-all parameter instead,
    // but we can also just return the leaf if ALL is present for safety.
    final fallbackHandler = node.verbHandlers[method] ?? node.verbHandlers['ALL'];
    if (fallbackHandler != null && fallbackHandler.route.endsWith('[^]*>')) {
        return MatchResult(fallbackHandler, Map.of(params));
    }
    
    // Priority 5: Similar logic as above but relying strictly on mounted routes. 
    // This is essentially a prefix match instead of exact match for `app.mount()`.
    if (fallbackHandler != null && (fallbackHandler.route.endsWith('/') || !fallbackHandler.route.contains(':') && !fallbackHandler.route.contains('<'))) {
        return MatchResult(fallbackHandler, Map.of(params));
    }

    return null; // No match found
  }
}

class MatchResult {
  final VerbHandler handlerInfo;
  final Map<String, String> params;

  MatchResult(this.handlerInfo, this.params);
}
