// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dot_notation.dart';

// **************************************************************************
// ShelfRouterGenerator
// **************************************************************************

Router _$DotNotationServiceRouter(DotNotationService service) {
  final router = Router();
  router.add('GET', r'/user/:id', service._getUser);
  router.add('GET', r'/post/:postId/comment/:commentId', service._getComment);
  return router;
}

class _$DotNotationService_getUserParams {
  _$DotNotationService_getUserParams(this._params);

  final Map<String, String> _params;

  String get id => _params['id']!;
}

extension _$DotNotationService_getUserRequest on Request {
  _$DotNotationService_getUserParams get _getUserParams =>
      _$DotNotationService_getUserParams(this.params);
}

class _$DotNotationService_getCommentParams {
  _$DotNotationService_getCommentParams(this._params);

  final Map<String, String> _params;

  String get postId => _params['postId']!;

  String get commentId => _params['commentId']!;
}

extension _$DotNotationService_getCommentRequest on Request {
  _$DotNotationService_getCommentParams get _getCommentParams =>
      _$DotNotationService_getCommentParams(this.params);
}
