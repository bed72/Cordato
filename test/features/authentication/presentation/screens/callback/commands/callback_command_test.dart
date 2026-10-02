import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/domain/enums/email_verification_status_enum.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/commands/callback_command.dart';

class _RepositoryMock extends Mock implements IAuthenticationRepository {}

void main() {
  test('confirms the URL when the command is executed', () async {
    final repository = _RepositoryMock();
    final command = CallbackCommand(repository: repository);
    addTearDown(command.dispose);
    verifyZeroInteractions(repository);
    when(() => repository.confirmEmail('signed'))
        .thenAnswer((_) async => EmailVerificationStatusEnum.success);
    expect(
      await command.execute.runAsync('signed'),
      EmailVerificationStatusEnum.success,
    );
    expect(command.execute.value, EmailVerificationStatusEnum.success);
    verify(() => repository.confirmEmail('signed')).called(1);
  });

  for (final status in [
    EmailVerificationStatusEnum.invalidLink,
    EmailVerificationStatusEnum.connectionFailure,
  ]) {
    test('exposes $status as a result of confirmation', () async {
      final repository = _RepositoryMock();
      final command = CallbackCommand(repository: repository);
      addTearDown(command.dispose);
      when(() => repository.confirmEmail('signed'))
          .thenAnswer((_) async => status);

      expect(await command.execute.runAsync('signed'), status);
      expect(command.execute.value, status);
    });
  }

  test(
    'exposes an unexpected repository exception as a command error',
    () async {
      final repository = _RepositoryMock();
      final command = CallbackCommand(repository: repository);
      addTearDown(command.dispose);
      final failure = StateError('repository unavailable');
      when(() => repository.confirmEmail('signed'))
          .thenAnswer((_) async => throw failure);

      void onResult() {}

      command.execute.results.addListener(onResult);
      try {
        await expectLater(
          command.execute.runAsync('signed'),
          throwsA(same(failure)),
        );
      } finally {
        command.execute.results.removeListener(onResult);
      }
    },
  );

  test(
    'shares an in-flight confirmation instead of repeating the GET',
    () async {
      final repository = _RepositoryMock();
      final command = CallbackCommand(repository: repository);
      addTearDown(command.dispose);
      final response = Completer<EmailVerificationStatusEnum>();
      when(() => repository.confirmEmail('signed'))
          .thenAnswer((_) => response.future);

      final first = command.execute.runAsync('signed');
      final second = command.execute.runAsync('signed');
      response.complete(EmailVerificationStatusEnum.success);

      expect(await first, EmailVerificationStatusEnum.success);
      expect(await second, EmailVerificationStatusEnum.success);
      verify(() => repository.confirmEmail('signed')).called(1);
    },
  );
}
