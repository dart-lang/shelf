// GENERATED CODE - DO NOT MODIFY BY HAND
// @dart=2.12

part of 'main.dart';

// **************************************************************************
// ShelfRouterGenerator
// **************************************************************************

Router _$ServiceRouter(Service service) {
  final router = Router();
  router.add('GET', r'/say-hi/<name>', service._hi);
  router.add('GET', r'/user/<userId|[0-9]+>', service._user);
  router.add('GET', r'/wave', service._wave);
  router.mount(r'/api/', service._api);
  router.all(r'/<ignored|.*>', service._notFound);
  return router;
}

Router _$ApiRouter(Api service) {
  final router = Router();
  router.add('GET', r'/messages', service._messages);
  router.add('GET', r'/messages/', service._messages);
  router.all(r'/<ignored|.*>', service._notFound);
  return router;
}
