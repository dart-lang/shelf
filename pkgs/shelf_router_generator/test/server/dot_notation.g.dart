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
