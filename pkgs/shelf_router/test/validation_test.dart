import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

void main() {
  test('Required rule', () {
    const rule = Required();
    expect(rule.validate('value'), isNull);
    expect(rule.validate(''), 'is required');
    expect(rule.validate(null), 'is required');
  });

  test('Number rule', () {
    const rule = Number();
    expect(rule.validate('42'), isNull);
    expect(rule.validate('3.14'), isNull);
    expect(rule.validate('abc'), 'must be a number');
    expect(rule.validate(''), isNull); // Required() should handle emptiness
  });

  test('Regex rule', () {
    final rule = Regex(RegExp(r'^\d{3}$'));
    expect(rule.validate('123'), isNull);
    expect(rule.validate('12'), 'is invalid');
    expect(rule.validate('1234'), 'is invalid');
    expect(rule.validate('abc'), 'is invalid');
  });

  test('Validation middleware success', () async {
    final router = Router();
    router.get('/user/:id', (Request request) {
      return Response.ok('User ${request.params['id']}');
    }, middleware: validate({'id': const Number()}));

    final response =
        await router(Request('GET', Uri.parse('http://localhost/user/42')));
    expect(response.statusCode, 200);
    expect(await response.readAsString(), 'User 42');
  });

  test('Validation middleware failure', () async {
    final router = Router();
    router.get('/user/:id', (Request request) {
      return Response.ok('User ${request.params['id']}');
    }, middleware: validate({'id': const Number()}));

    final response =
        await router(Request('GET', Uri.parse('http://localhost/user/abc')));
    expect(response.statusCode, 400);
    final body = jsonDecode(await response.readAsString());
    expect(body['error'], 'Validation failed');
    expect(body['details']['id'], 'must be a number');
  });

  test('Validation middleware multiple rules', () async {
    final router = Router();
    router.get('/user/:id', (Request request) {
      return Response.ok('User ${request.params['id']}');
    },
        middleware: validate({
          'id': const Number(),
          'type': const Required(),
        }));

    // Missing 'type' (it's not in the path, so it's null)
    final response =
        await router(Request('GET', Uri.parse('http://localhost/user/42')));
    expect(response.statusCode, 400);
    final body = jsonDecode(await response.readAsString());
    expect(body['details']['type'], 'is required');
  });
}
