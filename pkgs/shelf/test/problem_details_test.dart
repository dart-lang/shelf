import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('ProblemDetails constructor', () {
    test('status is 500 by default', () {
      final problemDetails = ProblemDetails();

      expect(problemDetails.status, 500);
    });

    test('sets default `type` if it is not specified', () {
      final problemDetails = ProblemDetails();

      expect(problemDetails.type, isNotNull);
    });

    test('sets default `title` if it is not specified', () {
      final problemDetails = ProblemDetails();

      expect(problemDetails.title, isNotNull);
    });

    test(
        'sets `type` to `about:blank` if it is not specified '
        'and there is not default value', () {
      // Sets status to non-existent value, to make sure that
      // the default value for `type` can not be found.
      final problemDetails = ProblemDetails(status: 1);

      expect(problemDetails.type, 'about:blank');
    });
  });

  group('ProblemDetails toJson()', () {
    test('removes pairs where a value is null (only for "standard" fields)',
        () {
      final problemDetails = ProblemDetails.raw(
        status: 1,
      );

      expect(problemDetails.toJson(), {'status': 1});
    });

    test('puts data of `extensions` on the top level of Map', () {
      final extensions = {
        'key1': 'value1',
        'key2': {
          'key3': 'value3',
        },
      };
      final problemDetails = ProblemDetails.raw(
        status: 1,
        extensions: extensions,
      );

      expect(
        problemDetails.toJson(),
        <String, Object?>{
          'status': 1,
        }..addAll(extensions),
      );
    });
  });

  group('fromJson()', () {
    test('all data except "standard" fields are related to `extensions`', () {
      final extensions = {
        'key1': 'value1',
        'key2': {
          'key3': 'value3',
        },
      };
      final problemDetails = ProblemDetails.raw(
        status: 1,
        extensions: extensions,
      );
      final jsonData = problemDetails.toJson();

      expect(
        ProblemDetails.fromJson(jsonData).extensions,
        extensions,
      );
    });
  });

  group('addOrUpdateExtension', () {
    test('adds new pair to `extensions` if it is not exist', () {
      final key = 'key';
      final value = 'value';
      final problemDetails = ProblemDetails();

      expect(
        problemDetails.addOrUpdateExtension(key, value).extensions,
        {key: value},
      );
    });

    test('updates a pair to `extensions` if exists', () {
      final key = 'key';
      final value1 = 'value1';
      final value2 = 'value2';
      final problemDetails = ProblemDetails(
        extensions: {
          key: value1,
        },
      );

      expect(
        problemDetails.addOrUpdateExtension(key, value2).extensions,
        {key: value2},
      );
    });
  });

  group('addOrUpdateExtensions', () {
    test('adds new pairs to `extensions` if they are not exist', () {
      final newExtensions = {
        'key1': 'value1',
        'key2': 'value2',
      };
      final problemDetails = ProblemDetails();

      expect(
        problemDetails.addOrUpdateExtensions(newExtensions).extensions,
        newExtensions,
      );
    });

    test('updates pairs to `extensions` if they exist', () {
      final key1 = 'key1';
      final key2 = 'key2';
      final oldExtensions = {
        key1: 'value1',
        key2: 'value2',
      };
      final newExtensions = {
        key1: 'value3',
        key2: 'value4',
      };
      final problemDetails = ProblemDetails(
        extensions: oldExtensions,
      );

      expect(
        problemDetails.addOrUpdateExtensions(newExtensions).extensions,
        newExtensions,
      );
    });
  });

  group('removeExtension', () {
    test('removes a pair from `extensions` if it exists', () {
      final key = 'key';
      final problemDetails = ProblemDetails(
        extensions: {
          key: 'value',
        },
      );

      expect(
        problemDetails.removeExtension(key).extensions,
        <String, Object?>{},
      );
    });
  });
}
