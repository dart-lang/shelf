// GENERATED CODE - DO NOT MODIFY BY HAND
// @dart=2.12

part of 'api.dart';

// **************************************************************************
// ShelfRouterGenerator
// **************************************************************************

Router _$ApiRouter(Api service) {
  final router = Router();
  router.add('GET', r'/time', service._time);
  router.add('GET', r'/to-uppercase/<word|.*>', service._toUpperCase);
  router.add('GET', r'/$string-escape', service._stringEscapingWorks);
  return router;
}
