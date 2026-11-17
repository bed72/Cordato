import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';

import '../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  late AuthenticationRepositoryMock mockRepository;
  late IAuthenticationRepository repository;

  setUp(() {
    mockRepository = AuthenticationRepositoryMock();
    repository = mockRepository;
  });

  group('IAuthenticationRepository', () {
    test('returns the user identifier using only the supplied email', () async {
      when(() => mockRepository.requestCode(email: ' User@example.com '))
          .thenAnswer((_) async => 'user-id');

      final String userId = await repository.requestCode(
        email: ' User@example.com ',
      );

      expect(userId, 'user-id');
      verify(() => mockRepository.requestCode(email: ' User@example.com '))
          .called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test(
      'confirms the supplied user identifier and code without output',
      () async {
        when(
          () =>
              mockRepository.confirmCode(userId: ' user-id ', code: ' 012345 '),
        ).thenAnswer((_) async {});

        final Future<void> confirmation = repository.confirmCode(
          userId: ' user-id ',
          code: ' 012345 ',
        );

        await expectLater(confirmation, completes);
        verify(
          () =>
              mockRepository.confirmCode(userId: ' user-id ', code: ' 012345 '),
        ).called(1);
        verifyNoMoreInteractions(mockRepository);
      },
    );

    test('signs out without credentials or output', () async {
      when(() => mockRepository.signOut()).thenAnswer((_) async {});

      final Future<void> logout = repository.signOut();

      await expectLater(logout, completes);
      verify(() => mockRepository.signOut()).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    for (final operation in ['request', 'confirm', 'signOut']) {
      test('$operation preserves expected application errors', () async {
        const errors = ErrorsEntity(
          errors: [
            ErrorEntity(status: '429', code: 'general_rate_limit_exceeded'),
          ],
        );
        final failure = AuthenticationException(errors: errors);
        when(() => mockRepository.requestCode(email: 'user@example.com'))
            .thenAnswer((_) async => throw failure);
        when(
          () => mockRepository.confirmCode(userId: 'user-id', code: '012345'),
        ).thenAnswer((_) async => throw failure);
        when(() => mockRepository.signOut())
            .thenAnswer((_) async => throw failure);

        final Future<Object?> pendingOperation = switch (operation) {
          'request' => repository.requestCode(email: 'user@example.com'),
          'confirm' => repository.confirmCode(
            userId: 'user-id',
            code: '012345',
          ),
          _ => repository.signOut(),
        };

        await expectLater(
          pendingOperation,
          throwsA(
            isA<AuthenticationException>()
                .having((exception) => exception, 'exception', same(failure))
                .having(
                  (exception) => exception.errors,
                  'errors',
                  same(errors),
                ),
          ),
        );
      });
    }
  });
}
