// GENERATED CODE - DO NOT MODIFY BY HAND
// @dart=2.12

part of 'service.dart';

// **************************************************************************
// ShelfRouterGenerator
// **************************************************************************

Router _$ServiceRouter(Service service) {
  final router = Router();
  router.add('GET', r'/say-hello', service._sayHello);
  router.add('GET', r'/say-hello/', service._sayHello);
  router.add('GET', r'/wave', service._wave);
  router.add('GET', r'/greet/<user>', service._greet);
  router.add('GET', r'/hi/<user>', service._hi);
  router.mount(r'/api/', service._api);
  router.all(r'/<_|.*>', service._index);
  return router;
}
