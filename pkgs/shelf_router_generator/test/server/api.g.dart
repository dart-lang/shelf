// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api.dart';

// **************************************************************************
// ShelfRouterGenerator
// **************************************************************************

Router _$ApiRouter(Api service) {
  final router = Router();
  router.add('GET', '/time', service._time);
  router.add('GET', '/to-uppercase/<word|.*>', service._toUpperCase);
  return router;
}
