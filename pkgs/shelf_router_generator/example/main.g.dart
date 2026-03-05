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
    middleware: const Pipeline()
        .addMiddleware(const ValidateParams({'name': Rule.string()}).middleware)
        .addMiddleware(
          const ValidateParams({'namex': Rule.string()}).middleware,
        )
        .middleware,
  );
  router.add(
    'GET',
    r'/user/:userId',
    service._user,
    middleware: const ValidateParams({'userId': Rule.number()}).middleware,
  );
  router.add('GET', r'/wave', service._wave);
  router.mount(r'/api', service._api.call);
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
