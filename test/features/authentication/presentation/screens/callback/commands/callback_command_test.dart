import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/domain/enums/email_status_enum.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/commands/callback_command.dart';

import '../../../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  test('confirms the URL when the command is executed', () async {
    final repository = AuthenticationRepositoryMock();
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
    EmailVerificationStatusEnum.invalid,
    EmailVerificationStatusEnum.failure,
  ]) {
    test('exposes $status as a result of confirmation', () async {
      final repository = AuthenticationRepositoryMock();
      final command = CallbackCommand(repository: repository);
      addTearDown(command.dispose);
      when(() => repository.confirmEmail('signed'))
          .thenAnswer((_) async => status);

      expect(command.execute.value, status);
      expect(await command.execute.runAsync('signed'), status);
    });
  }

  test(
    'exposes an unexpected repository exception as a command error',
    () async {
      final repository = AuthenticationRepositoryMock();
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
      final repository = AuthenticationRepositoryMock();
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

  test('does not query another link by joining an occupied command', () async {
    final repository = AuthenticationRepositoryMock();
    final command = CallbackCommand(repository: repository);

    addTearDown(command.dispose);

    final pending = Completer<EmailVerificationStatusEnum>();
    when(() => repository.confirmEmail('first'))
        .thenAnswer((_) => pending.future);

    when(() => repository.confirmEmail('second'))
        .thenAnswer((_) async => EmailVerificationStatusEnum.invalid);

    final first = command.execute.runAsync('first');
    final joined = command.execute.runAsync('second');

    expect(joined, same(first));
    pending.complete(EmailVerificationStatusEnum.success);

    expect(command.execute.results.value.paramData, 'first');
    expect(await joined, EmailVerificationStatusEnum.success);
    verifyNever(() => repository.confirmEmail('second'));

    expect(
      await command.execute.runAsync('second'),
      EmailVerificationStatusEnum.invalid,
    );
    expect(command.execute.results.value.paramData, 'second');
    verify(() => repository.confirmEmail('first')).called(1);
    verify(() => repository.confirmEmail('second')).called(1);
  });

  test(
    'disposal can complete a pending future with the previous status',
    () async {
      final repository = AuthenticationRepositoryMock();
      final command = CallbackCommand(repository: repository);

      when(() => repository.confirmEmail('first'))
          .thenAnswer((_) async => EmailVerificationStatusEnum.success);
      await command.execute.runAsync('first');

      final started = Completer<void>();
      final pending = Completer<EmailVerificationStatusEnum>();
      when(() => repository.confirmEmail('second')).thenAnswer((_) {
        started.complete();
        return pending.future;
      });

      final execution = command.execute.runAsync('second');
      await started.future;
      command.dispose();

      expect(await execution, EmailVerificationStatusEnum.success);

      pending.complete(EmailVerificationStatusEnum.invalid);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(command.execute.value, EmailVerificationStatusEnum.success);
      expect(
        command.execute.results.value.data,
        isNot(EmailVerificationStatusEnum.invalid),
      );
      verify(() => repository.confirmEmail('second')).called(1);
    },
  );
}
