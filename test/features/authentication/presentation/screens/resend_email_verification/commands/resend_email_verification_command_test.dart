import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/commands/resend_email_command.dart';
import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import '../../../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  void onResult() {}
  const email = 'person@example.com';
  late IAuthenticationRepository repository;
  late ResendEmailCommand command;

  setUp(() {
    repository = AuthenticationRepositoryMock();
    command = ResendEmailCommand(repository: repository);
    command.execute.results.addListener(onResult);
  });

  tearDown(() {
    command.execute.results.removeListener(onResult);
    command.dispose();
  });

  test('starts without acceptance or a repository call', () {
    expect(command.execute.value, isNull);
    expect(command.execute.results.value.hasError, isFalse);
    verifyZeroInteractions(repository);
  });

  test('resend passes the email and returns acceptance', () async {
    when(() => repository.resendEmail(email: email))
        .thenAnswer((_) async => const Right(true));

    final data = await command.execute.runAsync(email);

    expect(data, isTrue);
    expect(command.execute.value, isTrue);
    expect(command.execute.results.value.data, isTrue);
    expect(command.execute.results.value.paramData, email);
    verify(() => repository.resendEmail(email: email)).called(1);
  });

  test('resend keeps API errors in the command result', () async {
    const errors = ErrorsEntity(
      errors: [
        ErrorEntity(
          title: 'Aguarde',
          status: '429',
          detail: 'Aguarde antes de reenviar.',
          pointer: '/data/attributes/email',
          parameter: 'email',
        ),
        ErrorEntity(),
      ],
    );
    when(() => repository.resendEmail(email: email))
        .thenAnswer((_) async => const Left(errors));

    await expectLater(
      command.execute.runAsync(email),
      throwsA(
        isA<CommandFailureException>().having(
          (failure) => failure.errors,
          'errors',
          same(errors),
        ),
      ),
    );
    final failure =
        command.execute.results.value.error as CommandFailureException;
    expect(failure.errors, same(errors));
    expect(command.execute.results.value.hasError, isTrue);
    expect(command.execute.errors.value?.error, same(failure));
    expect(command.execute.value, isNull);
  });

  test(
    'exposes an unexpected repository exception as a command error',
    () async {
      final failure = StateError('repository unavailable');
      when(() => repository.resendEmail(email: email))
          .thenAnswer((_) async => throw failure);

      void onResult() {}

      command.execute.results.addListener(onResult);
      try {
        await expectLater(
          command.execute.runAsync(email),
          throwsA(same(failure)),
        );
        expect(command.execute.results.value.error, same(failure));
        expect(command.execute.errors.value?.error, same(failure));
      } finally {
        command.execute.results.removeListener(onResult);
      }
    },
  );

  test('publishes false without turning it into a failure', () async {
    when(() => repository.resendEmail(email: email))
        .thenAnswer((_) async => const Right(false));
    expect(await command.execute.runAsync(email), isFalse);
    expect(command.execute.value, isFalse);
    expect(command.execute.results.value.data, isFalse);
    expect(command.execute.results.value.hasError, isFalse);
  });

  test(
    'keeps empty failure distinct from prior acceptance and allows retry',
    () async {
      when(() => repository.resendEmail(email: email))
          .thenAnswer((_) async => const Right(true));
      await command.execute.runAsync(email);
      const errors = ErrorsEntity(errors: []);
      when(() => repository.resendEmail(email: email))
          .thenAnswer((_) async => const Left(errors));
      await expectLater(
        command.execute.runAsync(email),
        throwsA(
          isA<CommandFailureException>().having(
            (failure) => failure.errors,
            'errors',
            same(errors),
          ),
        ),
      );
      expect(command.execute.value, isTrue);
      expect(command.execute.results.value.data, isNull);
      expect(command.execute.results.value.hasError, isTrue);
      when(() => repository.resendEmail(email: email))
          .thenAnswer((_) async => const Right(true));
      expect(await command.execute.runAsync(email), isTrue);
      expect(command.execute.results.value.hasError, isFalse);
      verify(() => repository.resendEmail(email: email)).called(3);
    },
  );

  test('delegates email without normalization', () async {
    const input = '  Person@Example.com  ';
    when(() => repository.resendEmail(email: input))
        .thenAnswer((_) async => const Right(true));
    expect(await command.execute.runAsync(input), isTrue);
    verify(() => repository.resendEmail(email: input)).called(1);
  });
}
