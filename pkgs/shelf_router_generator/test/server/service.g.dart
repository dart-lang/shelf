// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service.dart';

// **************************************************************************
// ShelfRouterGenerator
// **************************************************************************

Router _$ServiceRouter(Service service) {
  final router = Router();
  router.add('GET', r'/say-hello', service._sayHello);
  router.add('GET', r'/say-hello/', service._sayHello);
  router.add('GET', r'/wave', service._wave);
  router.add('GET', r'/greet/:user', service._greet);
  router.add('GET', r'/hi/:user', service._hi);
  router.add(
    'GET',
    r'/user/:id',
    service._getUser,
    middleware: validateParams({'id': Rule.number()}),
  );
  router.add(
    'GET',
    r'/middleware-test',
    service._middlewareTest,
    middleware: (h) => validateParams({'test': Rule.number()})(
      validateParams({'foo': Rule.number()})(h),
    ),
  );
  router.mount(r'/api/', service._api);
  router.all(r'/:*_', service._index);
  return router;
}
