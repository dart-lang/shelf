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

class _$Service_greetParams {
  _$Service_greetParams(this._params);

  final Map<String, String> _params;

  String get user => _params['user']!;
}

extension _$Service_greetRequest on Request {
  _$Service_greetParams get _greetParams => _$Service_greetParams(this.params);
}

class _$Service_hiParams {
  _$Service_hiParams(this._params);

  final Map<String, String> _params;

  String get user => _params['user']!;
}

extension _$Service_hiRequest on Request {
  _$Service_hiParams get _hiParams => _$Service_hiParams(this.params);
}

class _$Service_getUserParams {
  _$Service_getUserParams(this._params);

  final Map<String, String> _params;

  String get id => _params['id']!;
}

extension _$Service_getUserRequest on Request {
  _$Service_getUserParams get _getUserParams =>
      _$Service_getUserParams(this.params);
}

class _$Service_indexParams {
  _$Service_indexParams(this._params);

  final Map<String, String> _params;

  String get _ => _params['_']!;
}

extension _$Service_indexRequest on Request {
  _$Service_indexParams get _indexParams => _$Service_indexParams(this.params);
}
