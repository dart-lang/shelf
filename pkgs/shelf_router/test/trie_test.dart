import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

void main() {
  Future<Response> get(Router router, String path) async {
    return await router
        .call(Request('GET', Uri.parse('http://localhost$path')));
  }

  test('handles root paths correctly', () async {
    final router = Router();
    router.get('/', (Request request) => Response.ok('root1'));
    router.get('/api', (Request request) => Response.ok('root2'));

    var response = await get(router, '/');
    expect(await response.readAsString(), 'root1');

    response = await get(router, '/api');
    expect(await response.readAsString(), 'root2');
  });

  test('handles trailing slashes strictly', () async {
    final router = Router();
    router.get('/users', (Request request) => Response.ok('users'));
    router.get('/users/', (Request request) => Response.ok('usersTrailing'));

    var response = await get(router, '/users');
    expect(await response.readAsString(), 'users');

    response = await get(router, '/users/');
    expect(await response.readAsString(), 'usersTrailing');
  });

  test('stops parsing static prefix at first parameter', () async {
    final router = Router();
    router.get('/<user>/details',
        (Request request, String user) => Response.ok('immediateParam-$user'));

    var response = await get(router, '/alice/details');
    expect(await response.readAsString(), 'immediateParam-alice');
  });

  test('handles mid-segment parameters properly', () async {
    final router = Router();
    router.get('/files/image_<id>.png',
        (Request request, String id) => Response.ok('midSegmentParam-$id'));

    var response = await get(router, '/files/image_123.png');
    expect(await response.readAsString(), 'midSegmentParam-123');
  });

  test('maintains registration priority regardless of route specificity',
      () async {
    final router = Router();
    router.get('/<any|.*>', (Request request) => Response.ok('catchAll'));
    router.get('/users/details', (Request request) => Response.ok('specific'));
    router.get(
        '/users/<id>', (Request request, String id) => Response.ok('wildcard'));

    var response = await get(router, '/users/details');
    expect(await response.readAsString(), 'catchAll');
  });

  test('isolates unrelated branches', () async {
    final router = Router();
    router.get('/users', (Request request) => Response.ok('users'));
    router.get('/admins', (Request request) => Response.ok('admins'));

    var response = await get(router, '/users');
    expect(await response.readAsString(), 'users');

    response = await get(router, '/admins');
    expect(await response.readAsString(), 'admins');
  });
}
