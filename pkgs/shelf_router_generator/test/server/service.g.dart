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
  router.add('GET', r'/greet/<user>', service._greet);
  router.add('GET', r'/hi/<user>', service._hi);
  router.mount(r'/api/', service._api.call);
  router.all(r'/<_|.*>', service._index);
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

class _$Service_indexParams {
  _$Service_indexParams(this._params);

  final Map<String, String> _params;

  String get _ => _params['_']!;
}

extension _$Service_indexRequest on Request {
  _$Service_indexParams get _indexParams => _$Service_indexParams(this.params);
}
