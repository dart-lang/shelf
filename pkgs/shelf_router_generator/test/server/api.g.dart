// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api.dart';

// **************************************************************************
// ShelfRouterGenerator
// **************************************************************************

Router _$ApiRouter(Api service) {
  final router = Router();
  router.add('GET', r'/time', service._time);
  router.add('GET', r'/to-uppercase/<word|.*>', service._toUpperCase);
  router.add('GET', r'/$string-escape', service._stringEscapingWorks);
  return router;
}

class _$Api_toUpperCaseParams {
  _$Api_toUpperCaseParams(this._params);

  final Map<String, String> _params;

  String get word => _params['word']!;
}

extension _$Api_toUpperCaseRequest on Request {
  _$Api_toUpperCaseParams get _toUpperCaseParams =>
      _$Api_toUpperCaseParams(this.params);
}
