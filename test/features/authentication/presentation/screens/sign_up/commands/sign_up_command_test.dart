import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import 'package:cordato/features/authentication/presentation/screens/sign_up/commands/sign_up_command.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';

import '../../../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  void onResult() {}
  const credentials = (email: 'person@example.com', password: 'secret');

  late IAuthenticationRepository repository;
  late SignUpCommand command;

  setUp(() {
    repository = AuthenticationRepositoryMock();
    command = SignUpCommand(repository: repository);
    command.execute.results.addListener(onResult);
  });

  tearDown(() {
    command.execute.results.removeListener(onResult);
    command.dispose();
  });

  test('starts without a registration or a repository call', () {
    expect(command.execute.value, isNull);
    expect(command.execute.results.value.hasError, isFalse);
    verifyZeroInteractions(repository);
  });

  test('sign-up returns the registration result', () async {
    when(
      () => repository.signUp(
        email: credentials.email,
        password: credentials.password,
      ),
    ).thenAnswer((_) async => const Right(true));

    final data = await command.execute.runAsync(credentials);

    expect(data, isTrue);
    expect(command.execute.value, isTrue);
    expect(command.execute.results.value.data, isTrue);
    expect(command.execute.results.value.paramData, credentials);
    verify(
      () => repository.signUp(
        email: credentials.email,
        password: credentials.password,
      ),
    ).called(1);
  });

  test('sign-up preserves the error list in the command result', () async {
    const errors = ErrorsEntity(
      errors: [
        ErrorEntity(
          title: 'Conflito',
          status: '409',
          detail: 'E-mail já cadastrado.',
          pointer: '/data/attributes/email',
          parameter: 'email',
        ),
        ErrorEntity(),
      ],
    );
    when(
      () => repository.signUp(
        email: credentials.email,
        password: credentials.password,
      ),
    ).thenAnswer((_) async => const Left(errors));

    await expectLater(
      command.execute.runAsync(credentials),
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
      when(
        () => repository.signUp(
          email: credentials.email,
          password: credentials.password,
        ),
      ).thenAnswer((_) async => throw failure);

      void onResult() {}

      command.execute.results.addListener(onResult);
      try {
        await expectLater(
          command.execute.runAsync(credentials),
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
    when(
      () => repository.signUp(
        email: credentials.email,
        password: credentials.password,
      ),
    ).thenAnswer((_) async => const Right(false));
    expect(await command.execute.runAsync(credentials), isFalse);
    expect(command.execute.value, isFalse);
    expect(command.execute.results.value.data, isFalse);
    expect(command.execute.results.value.hasError, isFalse);
  });

  test(
    'keeps empty failure distinct from prior acceptance and allows retry',
    () async {
      when(
        () => repository.signUp(
          email: credentials.email,
          password: credentials.password,
        ),
      ).thenAnswer((_) async => const Right(true));
      await command.execute.runAsync(credentials);
      const errors = ErrorsEntity(errors: []);
      when(
        () => repository.signUp(
          email: credentials.email,
          password: credentials.password,
        ),
      ).thenAnswer((_) async => const Left(errors));
      await expectLater(
        command.execute.runAsync(credentials),
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
      when(
        () => repository.signUp(
          email: credentials.email,
          password: credentials.password,
        ),
      ).thenAnswer((_) async => const Right(true));
      expect(await command.execute.runAsync(credentials), isTrue);
      expect(command.execute.results.value.hasError, isFalse);
      verify(
        () => repository.signUp(
          email: credentials.email,
          password: credentials.password,
        ),
      ).called(3);
    },
  );

  test('delegates credentials without normalization', () async {
    const input = (email: '  Person@Example.com  ', password: ' secret ');
    when(() => repository.signUp(email: input.email, password: input.password))
        .thenAnswer((_) async => const Right(true));
    expect(await command.execute.runAsync(input), isTrue);
    verify(
      () => repository.signUp(email: input.email, password: input.password),
    ).called(1);
  });

  test(
    'shares pending registration without submitting other credentials',
    () async {
      final pending = Completer<SignUpRepositoryType>();
      final other = SignUpCommand(repository: repository);
      addTearDown(other.dispose);
      when(
        () => repository.signUp(
          email: credentials.email,
          password: credentials.password,
        ),
      ).thenAnswer((_) => pending.future);

      final execution = command.execute.runAsync(credentials);
      command.execute.run(credentials);
      final joined = command.execute.runAsync((
        password: 'other',
        email: 'other@example.com',
      ));

      expect(joined, same(execution));
      expect(command.execute.isRunning.value, isTrue);
      pending.complete(const Right(true));

      expect(await joined, isTrue);
      expect(await execution, isTrue);
      expect(other.execute.value, isNull);
      expect(command.execute.results.value.paramData, credentials);
      expect(other.execute.results.value.data, isNull);
      verify(
        () => repository.signUp(
          email: credentials.email,
          password: credentials.password,
        ),
      ).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  test(
    'does not publish acceptance when disposed during registration',
    () async {
      final started = Completer<void>();
      final pending = Completer<SignUpRepositoryType>();
      final disposable = SignUpCommand(repository: repository);
      when(
        () => repository.signUp(
          email: credentials.email,
          password: credentials.password,
        ),
      ).thenAnswer((_) {
        started.complete();
        return pending.future;
      });

      final execution = disposable.execute.runAsync(credentials);
      await started.future;
      disposable.dispose();
      pending.complete(const Right(true));

      expect(await execution, isNull);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(disposable.execute.value, isNull);
      expect(disposable.execute.results.value.data, isNull);
      verify(
        () => repository.signUp(
          email: credentials.email,
          password: credentials.password,
        ),
      ).called(1);
    },
  );
}
