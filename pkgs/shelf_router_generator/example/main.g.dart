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

class _$Service_hiParams {
  _$Service_hiParams(this._params);

  final Map<String, String> _params;

  String get name => _params['name']!;
}

extension _$Service_hiRequest on Request {
  _$Service_hiParams get _hiParams => _$Service_hiParams(this.params);
}

class _$Service_userParams {
  _$Service_userParams(this._params);

  final Map<String, String> _params;

  String get userId => _params['userId']!;
}

extension _$Service_userRequest on Request {
  _$Service_userParams get _userParams => _$Service_userParams(this.params);
}

class _$Service_notFoundParams {
  _$Service_notFoundParams(this._params);

  final Map<String, String> _params;

  String get ignored => _params['ignored']!;
}

extension _$Service_notFoundRequest on Request {
  _$Service_notFoundParams get _notFoundParams =>
      _$Service_notFoundParams(this.params);
}

Router _$ApiRouter(Api service) {
  final router = Router();
  router.add('GET', r'/messages', service._messages);
  router.add('GET', r'/messages/', service._messages);
  router.all(r'/:*ignored', service._notFound);
  return router;
}

class _$Api_notFoundParams {
  _$Api_notFoundParams(this._params);

  final Map<String, String> _params;

  String get ignored => _params['ignored']!;
}

extension _$Api_notFoundRequest on Request {
  _$Api_notFoundParams get _notFoundParams => _$Api_notFoundParams(this.params);
}
