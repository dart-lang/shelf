import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

void main() {
  group('Rule Constraints', () {
    test('Rule.string allows valid range', () {
      expect(() => const Rule.string(min: 5, max: 10), returnsNormally);
    });

    test('Rule.string throws if min > max', () {
      // Note: Since these are const constructors, we are testing them at runtime
      // here, but they will also throw at compile-time.
      expect(
          () => Rule.string(min: 11, max: 10), throwsA(isA<AssertionError>()));
    });

    test('Rule.string throws if min is negative', () {
      expect(() => Rule.string(min: -1), throwsA(isA<AssertionError>()));
    });

    test('Rule.string throws if max is negative', () {
      expect(() => Rule.string(max: -1), throwsA(isA<AssertionError>()));
    });

    test('Rule.number allows valid range', () {
      expect(() => const Rule.number(min: 0, max: 100), returnsNormally);
    });

    test('Rule.number throws if min > max', () {
      expect(() => Rule.number(min: 101, max: 100),
          throwsA(isA<AssertionError>()));
    });

    test('Rule.number throws if min is negative', () {
      expect(() => Rule.number(min: -5), throwsA(isA<AssertionError>()));
    });
  });

  group('Rule Validation Logic', () {
    test('Rule.string length constraints', () {
      const rule = Rule.string(min: 3, max: 5);
      expect(rule.validate('abc'), isNull);
      expect(rule.validate('ab'), 'must be at least 3 characters');
      expect(rule.validate('abcdef'), 'must be at most 5 characters');
    });

    test('Rule.number range constraints', () {
      const rule = Rule.number(min: 10, max: 20);
      expect(rule.validate('15'), isNull);
      expect(rule.validate('5'), 'must be at least 10');
      expect(rule.validate('25'), 'must be at most 20');
      expect(rule.validate('abc'), 'must be a number');
    });

    test('Rule.string regex matches', () {
      const rule = Rule.string(matches: r'^\d+$');
      expect(rule.validate('123'), isNull);
      expect(rule.validate('abc'), 'is invalid');
    });
  });
}
