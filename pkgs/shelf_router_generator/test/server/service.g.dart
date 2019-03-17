// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service.dart';

// **************************************************************************
// ShelfRouterGenerator
// **************************************************************************

Router _$ServiceRouter(Service service) {
  final router = Router();
  router.add('GET', '/say-hello', service._sayHello);
  router.add('GET', '/say-hello/', service._sayHello);
  router.add('GET', '/wave', service._wave);
  router.add('GET', '/greet/<user>', service._greet);
  router.add('GET', '/hi/<user>', service._hi);
  router.mount('/api/', service._api);
  router.all('/<_|.*>', service._index);
  return router;
}
