import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import 'package:cordato/features/authentication/presentation/commands/logout_command.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';

import '../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  void onResult() {}
  late IAuthenticationRepository repository;
  late LogoutCommand command;

  setUp(() {
    repository = AuthenticationRepositoryMock();
    command = LogoutCommand(repository: repository);
    command.execute.results.addListener(onResult);
  });

  tearDown(() {
    command.execute.results.removeListener(onResult);
    command.dispose();
  });

  test('starts without a logout or a repository call', () {
    expect(command.execute.value, isNull);
    expect(command.execute.results.value.hasError, isFalse);
    verifyZeroInteractions(repository);
  });

  test('delegates logout and publishes repository success', () async {
    when(() => repository.logout()).thenAnswer((_) async => const Right(true));

    expect(command.execute.value, isNull);
    final data = await command.execute.runAsync();

    expect(data, isTrue);
    expect(command.execute.value, isTrue);
    expect(command.execute.results.value.data, isTrue);
    verify(() => repository.logout()).called(1);
  });

  test('preserves repository errors as a command result', () async {
    const errors = ErrorsEntity(
      errors: [
        ErrorEntity(
          status: '403',
          parameter: 'status',
          title: 'Não autorizado',
          detail: 'Conta bloqueada.',
          pointer: '/data/attributes/status',
        ),
        ErrorEntity(),
      ],
    );
    when(() => repository.logout()).thenAnswer((_) async => const Left(errors));

    await expectLater(
      command.execute.runAsync(),
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

  test('prevents additional execution while logout is pending', () async {
    final pending = Completer<LogoutRepositoryType>();
    when(() => repository.logout()).thenAnswer((_) => pending.future);

    final data = command.execute.runAsync();
    await Future<void>.delayed(Duration.zero);

    expect(command.execute.isRunning.value, isTrue);

    command.execute.run();
    verify(() => repository.logout()).called(1);
    pending.complete(const Right(true));

    expect(await data, isTrue);

    await Future<void>.delayed(Duration.zero);

    expect(command.execute.isRunning.value, isFalse);
    verifyNoMoreInteractions(repository);
  });

  test('exposes unexpected repository exceptions as command errors', () async {
    final failure = StateError('repository unavailable');
    when(() => repository.logout()).thenAnswer((_) async => throw failure);

    void onResult() {}
    command.execute.results.addListener(onResult);
    try {
      await expectLater(command.execute.runAsync(), throwsA(same(failure)));
      expect(command.execute.results.value.error, same(failure));
      expect(command.execute.errors.value?.error, same(failure));
    } finally {
      command.execute.results.removeListener(onResult);
    }
  });

  test('publishes false without turning it into a failure', () async {
    when(() => repository.logout()).thenAnswer((_) async => const Right(false));
    expect(await command.execute.runAsync(), isFalse);
    expect(command.execute.value, isFalse);
    expect(command.execute.results.value.data, isFalse);
    expect(command.execute.results.value.hasError, isFalse);
  });

  test(
    'keeps empty failure distinct from prior logout and allows retry',
    () async {
      when(() => repository.logout())
          .thenAnswer((_) async => const Right(true));
      await command.execute.runAsync();
      const errors = ErrorsEntity(errors: []);
      when(() => repository.logout())
          .thenAnswer((_) async => const Left(errors));
      await expectLater(
        command.execute.runAsync(),
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
      when(() => repository.logout())
          .thenAnswer((_) async => const Right(true));
      expect(await command.execute.runAsync(), isTrue);
      expect(command.execute.results.value.hasError, isFalse);
      verify(() => repository.logout()).called(3);
    },
  );
}
