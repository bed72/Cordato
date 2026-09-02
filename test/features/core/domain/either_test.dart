import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/either.dart';

void main() {
  group('Either', () {
    test('recognizes Left and exposes its value', () {
      final either = Left<String, int>('error');

      expect(either.isLeft, isTrue);
      expect(either.isRight, isFalse);
      expect(either.left, equals('error'));
      expect(() => either.right, throwsA(isA<StateError>()));
    });

    test('recognizes Right and exposes its value', () {
      final either = Right<String, int>(42);

      expect(either.isRight, isTrue);
      expect(either.isLeft, isFalse);
      expect(either.right, equals(42));
      expect(() => either.left, throwsA(isA<StateError>()));
    });

    test('folds Left and Right with the matching function', () {
      final left = Left<String, int>('error')
          .fold((value) => value.length, (value) => value);
      final right = Right<String, int>(42)
          .fold((value) => value.length, (value) => value);

      expect(left, equals(5));
      expect(right, equals(42));
    });

    test('mapRight transforms only Right', () {
      final right = Right<String, int>(2).mapRight((number) => number * 2);
      final left = Left<String, int>('fail').mapRight((number) => number * 2);

      expect(right, equals(Right<String, int>(4)));
      expect(left, equals(Left<String, int>('fail')));
    });

    test('mapLeft transforms only Left', () {
      final left = Left<String, int>('fail')
          .mapLeft((message) => message.toUpperCase());
      final right = Right<String, int>(10)
          .mapLeft((message) => message.toUpperCase());

      expect(left, equals(Left<String, int>('FAIL')));
      expect(right, equals(Right<String, int>(10)));
    });

    test('flatMap chains Right values', () {
      final data = Right<String, int>(2)
          .flatMap((number) => Right<String, String>('value: $number'));

      expect(data, equals(Right<String, String>('value: 2')));
    });

    test('flatMap propagates Left', () {
      final data = Left<String, int>('error')
          .flatMap((_) => Right<String, String>('ok'));

      expect(data, equals(Left<String, String>('error')));
    });

    test('either transforms both sides', () {
      final left = Left<int, String>(10)
          .either((value) => value * 2, (value) => value.length);
      final right = Right<int, String>('abc')
          .either((value) => value * 2, (value) => value.length);

      expect(left, equals(Left<int, int>(20)));
      expect(right, equals(Right<int, int>(3)));
    });

    test('swap converts Left to Right and Right to Left', () {
      final right = Right<String, int>(42).swap();
      final left = Left<String, int>('fail').swap();

      expect(right, equals(Left<int, String>(42)));
      expect(left, equals(Right<int, String>('fail')));
    });

    test('tryCatch returns Right on success', () {
      final data = Either.tryCatch<String, int, FormatException>(
        (exception) => exception.toString(),
        () => int.parse('123'),
      );

      expect(data, equals(Right<String, int>(123)));
    });

    test('tryCatch returns Left on the expected exception', () {
      final data = Either.tryCatch<String, int, FormatException>(
        (_) => 'bad format',
        () => int.parse('abc'),
      );

      expect(data, equals(Left<String, int>('bad format')));
    });

    test('tryExcept returns Right on success', () {
      final data = Either.tryExcept<FormatException, int>(
        () => int.parse('42'),
      );

      expect(data, equals(Right<FormatException, int>(42)));
    });

    test('tryExcept returns Left on the expected exception', () {
      final data = Either.tryExcept<FormatException, int>(
        () => int.parse('abc'),
      );

      expect(data.isLeft, isTrue);
      expect(data.left, isA<FormatException>());
    });

    test('cond returns the matching side', () {
      expect(
        Either.cond(true, 'fail', 42),
        equals(const Right<String, int>(42)),
      );
      expect(
        Either.cond(false, 'fail', 42),
        equals(const Left<String, int>('fail')),
      );
    });

    test('condLazy evaluates only the selected branch', () {
      var leftCalled = false;
      var rightCalled = false;

      final right = Either.condLazy(
        true,
        () {
          leftCalled = true;
          return 'fail';
        },
        () {
          rightCalled = true;
          return 99;
        },
      );

      expect(leftCalled, isFalse);
      expect(rightCalled, isTrue);
      expect(right, equals(const Right<String, int>(99)));
    });

    test('equality compares values and variants correctly', () {
      expect(Left('x'), equals(Left('x')));
      expect(Right(42), equals(Right(42)));
      expect(Left('x'), isNot(equals(Right('x'))));
    });

    test('equal values have equal hash codes', () {
      expect(Left('x').hashCode, equals(Left('x').hashCode));
      expect(Right(42).hashCode, equals(Right(42).hashCode));
    });
  });
}
