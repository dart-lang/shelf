import 'dart:async' show Future;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

part 'dot_notation.g.dart';

class DotNotationService {
  @Route.get('/user/:id')
  Future<Response> _getUser(Request request) async {
    final params = request._getUserParams;
    return Response.ok('User ${params.id}');
  }

  @Route.get('/post/:postId/comment/:commentId')
  Response _getComment(Request request) {
    final params = request._getCommentParams;
    return Response.ok('Post ${params.postId}, Comment ${params.commentId}');
  }

  Router get router => _$DotNotationServiceRouter(this);
}
