import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/data/repositories/authentication_repository.dart';
import 'package:cordato/features/authentication/domain/failures/authentication_failure.dart';
import 'package:cordato/features/authentication/infrastructure/remoto/authentication_data_source.dart';
import 'package:cordato/features/core/domain/either.dart';

class _AuthenticationDataSourceMock extends Mock
    implements IAuthenticationDataSource {}

void main() {
  const email = 'person@example.com';
  const code = 'magic-link-code';

  late IAuthenticationDataSource dataSource;
  late AuthenticationRepository repository;

  setUp(() {
    dataSource = _AuthenticationDataSourceMock();
    repository = AuthenticationRepository(dataSource: dataSource);
  });

  group('AuthenticationRepository', () {
    test('returns Right when logout succeeds', () async {
      when(() => dataSource.logout()).thenAnswer((_) async => true);

      final result = await repository.logout();

      expect(result, equals(const Right<Failure, void>(null)));
      verify(() => dataSource.logout()).called(1);
    });

    test('returns LogoutFailure when logout fails', () async {
      when(() => dataSource.logout()).thenAnswer((_) async => false);

      final result = await repository.logout();

      expect(result.left, isA<LogoutFailure>());
    });

    test('returns Right when a session exists', () async {
      when(() => dataSource.checkSession()).thenAnswer((_) async => true);

      final result = await repository.checkSession();

      expect(result, equals(const Right<Failure, void>(null)));
      verify(() => dataSource.checkSession()).called(1);
    });

    test('returns UnknownFailure when no session exists', () async {
      when(() => dataSource.checkSession()).thenAnswer((_) async => false);

      final result = await repository.checkSession();

      expect(result.left, isA<UnknownFailure>());
    });

    test('returns Right when magic link request succeeds', () async {
      when(() => dataSource.requestMagicLink(email: email))
          .thenAnswer((_) async => true);

      final result = await repository.requestMagicLink(email: email);

      expect(result, equals(const Right<Failure, void>(null)));
      verify(() => dataSource.requestMagicLink(email: email)).called(1);
    });

    test('returns MagicLinkRequestFailure when request fails', () async {
      when(() => dataSource.requestMagicLink(email: email))
          .thenAnswer((_) async => false);

      final result = await repository.requestMagicLink(email: email);

      expect(result.left, isA<MagicLinkRequestFailure>());
    });

    test('returns Right when magic link completion succeeds', () async {
      when(() => dataSource.completeMagicLink(code: code))
          .thenAnswer((_) async => true);

      final result = await repository.completeMagicLink(
        code: code,
        flowId: 'flow-id',
      );

      expect(result, equals(const Right<Failure, void>(null)));
      verify(() => dataSource.completeMagicLink(code: code)).called(1);
    });

    test(
      'returns MagicLinkConfirmationFailure when completion fails',
      () async {
        when(() => dataSource.completeMagicLink(code: code))
            .thenAnswer((_) async => false);

        final result = await repository.completeMagicLink(code: code);

        expect(result.left, isA<MagicLinkConfirmationFailure>());
      },
    );
  });
}
