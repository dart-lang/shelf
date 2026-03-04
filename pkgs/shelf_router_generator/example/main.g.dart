// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main.dart';

// **************************************************************************
// ShelfRouterGenerator
// **************************************************************************

Router _$ServiceRouter(Service service) {
  final router = Router();
  router.add(
    'GET',
    r'/say-hi/:name',
    service._hi,
    middleware: validateParams({'name': Rule.string(min: 5, max: 10)}),
  );
  router.add(
    'GET',
    r'/user/:userId',
    service._user,
    middleware: validateParams({'userId': Rule.number()}),
  );
  router.add('GET', r'/wave', service._wave);
  router.mount(r'/api', service._api);
  router.all(r'/:*ignored', service._notFound);
  return router;
}

Router _$ApiRouter(Api service) {
  final router = Router();
  router.add('GET', r'/messages', service._messages);
  router.add('GET', r'/messages/', service._messages);
  router.all(r'/:*ignored', service._notFound);
  return router;
}
