// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main.dart';

// **************************************************************************
// ShelfRouterGenerator
// **************************************************************************

Router _$ServiceRouter(Service service) {
  final router = Router();
  router.add('GET', '/say-hi/<name>', service._hi);
  router.add('GET', '/user/<userId|[0-9]+>', service._user);
  router.add('GET', '/wave', service._wave);
  router.mount('/api/', service._api);
  router.all('/<ignored|.*>', service._404);
  return router;
}

Router _$ApiRouter(Api service) {
  final router = Router();
  router.add('GET', '/messages', service._messages);
  router.add('GET', '/messages/', service._messages);
  router.all('/<ignored|.*>', service._404);
  return router;
}
