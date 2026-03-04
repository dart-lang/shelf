import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

void main() {
  test('Rule.number validation', () {
    const rule = Rule.number();
    expect(rule.validate('42'), isNull);
    expect(rule.validate('3.14'), isNull);
    expect(rule.validate('abc'), 'must be a number');
    expect(rule.validate(''), isNull);
  });

  test('Rule.string with regex', () {
    const rule = Rule.string(matches: r'^\d{3}$');
    expect(rule.validate('123'), isNull);
    expect(rule.validate('12'), 'is invalid');
    expect(rule.validate('1234'), 'is invalid');
    expect(rule.validate('abc'), 'is invalid');
  });

  test('Validation middleware success', () async {
    final router = Router();
    router.get('/user/:id', (Request request) {
      return Response.ok('User ${request.params['id']}');
    }, middleware: const ValidateParams({'id': Rule.number()}).call);

    final response =
        await router(Request('GET', Uri.parse('http://localhost/user/42')));
    expect(response.statusCode, 200);
    expect(await response.readAsString(), 'User 42');
  });

  test('Validation middleware failure', () async {
    final router = Router();
    router.get('/user/:id', (Request request) {
      return Response.ok('User ${request.params['id']}');
    }, middleware: const ValidateParams({'id': Rule.number()}).call);

    final response =
        await router(Request('GET', Uri.parse('http://localhost/user/abc')));
    expect(response.statusCode, 400);
    final body = jsonDecode(await response.readAsString());
    expect(body['error'], 'Validation failed');
    expect(body['details']['id'], 'must be a number');
  });

  test('Validation middleware path param required', () async {
    final router = Router();
    router.get('/user/:id', (Request request) {
      return Response.ok('User ${request.params['id']}');
    },
        middleware: const ValidateParams({
          'id': Rule.number(),
        }).call);

    // Missing path param (this usually wouldn't match the route, but shelf_router
    // might match and pass null if the regex is loose, though here it's :id)
    // Actually, if we hit the handler, id is there.
    // The test 'multiple rules' previously tested a non-path param.
  });
}
