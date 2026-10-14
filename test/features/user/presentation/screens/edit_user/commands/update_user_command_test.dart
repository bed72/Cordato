import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/domain/repositories/interface_user_repository.dart';
import 'package:cordato/features/user/presentation/screens/edit_user/commands/update_user_command.dart';

import '../../../../../../support/user/mocks/user_repository_mock.dart';

void main() {
  void onResult() {}
  const user = UserEntity(
    id: 'user-1',
    status: 'active',
    name: 'Nome atualizado',
    email: 'person@example.com',
  );
  late UpdateUserCommand command;
  late UserRepositoryMock repository;

  setUp(() {
    repository = UserRepositoryMock();
    command = UpdateUserCommand(repository: repository);
    command.execute.results.addListener(onResult);
  });

  tearDown(() {
    command.execute.results.removeListener(onResult);
    command.dispose();
  });

  test('starts without a result or an update', () {
    expect(command.execute.value, isNull);
    expect(command.execute.isRunning.value, isFalse);
    expect(command.execute.results.value.hasError, isFalse);
    verifyZeroInteractions(repository);
  });

  test('updates the current user and publishes the API result', () async {
    when(() => repository.update(name: user.name))
        .thenAnswer((_) async => const Right(user));

    final response = await command.execute.runAsync(user.name);

    expect(response, same(user));
    expect(command.execute.value, same(user));
    expect(command.execute.results.value.data, same(user));
    verify(() => repository.update(name: user.name)).called(1);
    verifyNoMoreInteractions(repository);
  });

  test('preserves validation errors for presentation feedback', () async {
    const errors = ErrorsEntity(
      errors: [
        ErrorEntity(
          status: '422',
          parameter: 'name',
          pointer: '/data/attributes/name',
          detail: 'Informe um nome válido.',
        ),
        ErrorEntity(title: 'Falha adicional'),
      ],
    );
    when(() => repository.update(name: user.name))
        .thenAnswer((_) async => const Left(errors));

    await expectLater(
      command.execute.runAsync(user.name),
      throwsA(
        isA<CommandFailureException>().having(
          (failure) => failure.errors,
          'errors',
          same(errors),
        ),
      ),
    );
    expect(command.execute.value, isNull);
    expect(command.execute.results.value.hasError, isTrue);
    expect(
      (command.execute.results.value.error as CommandFailureException).errors,
      same(errors),
    );
    expect(
      command.execute.errors.value?.error,
      same(command.execute.results.value.error),
    );
  });

  test('prevents additional updates while a request is pending', () async {
    final started = Completer<void>();
    final pending = Completer<UpdateRepositoryType>();

    when(() => repository.update(name: user.name)).thenAnswer((_) {
      started.complete();
      return pending.future;
    });

    final response = command.execute.runAsync(user.name);
    await started.future;

    expect(command.execute.isRunning.value, isTrue);

    command.execute.run(user.name);
    final joined = command.execute.runAsync('Outro nome');

    expect(joined, same(response));

    verify(() => repository.update(name: user.name)).called(1);
    pending.complete(const Right(user));

    expect(await joined, same(user));
    expect(await response, same(user));
    expect(command.execute.isRunning.value, isFalse);
    expect(command.execute.results.value.paramData, user.name);
    verifyNoMoreInteractions(repository);
  });

  test('exposes unexpected repository exceptions as command errors', () async {
    void onResult() {}
    final failure = StateError('repository unavailable');

    when(() => repository.update(name: user.name))
        .thenAnswer((_) async => throw failure);

    command.execute.results.addListener(onResult);

    try {
      await expectLater(
        command.execute.runAsync(user.name),
        throwsA(same(failure)),
      );

      expect(command.execute.results.value.error, same(failure));
      expect(command.execute.errors.value?.error, same(failure));
    } finally {
      command.execute.results.removeListener(onResult);
    }
  });

  test('delegates the name without normalization', () async {
    const name = '  Nome atualizado  ';
    when(() => repository.update(name: name))
        .thenAnswer((_) async => const Right(user));

    expect(await command.execute.runAsync(name), same(user));
    expect(command.execute.results.value.paramData, name);
    verify(() => repository.update(name: name)).called(1);
    verifyNoMoreInteractions(repository);
  });

  test(
    'keeps empty failure separate from a previous user and allows retry',
    () async {
      when(() => repository.update(name: user.name))
          .thenAnswer((_) async => const Right(user));

      await command.execute.runAsync(user.name);

      const errors = ErrorsEntity(errors: []);

      when(() => repository.update(name: user.name))
          .thenAnswer((_) async => const Left(errors));

      await expectLater(
        command.execute.runAsync(user.name),
        throwsA(
          isA<CommandFailureException>().having(
            (failure) => failure.errors,
            'errors',
            same(errors),
          ),
        ),
      );

      expect(command.execute.value, same(user));
      expect(command.execute.results.value.data, isNull);
      expect(command.execute.results.value.hasError, isTrue);
      expect(
        command.execute.errors.value?.error,
        same(command.execute.results.value.error),
      );

      when(() => repository.update(name: user.name))
          .thenAnswer((_) async => const Right(user));

      expect(await command.execute.runAsync(user.name), same(user));
      expect(command.execute.results.value.hasError, isFalse);
      verify(() => repository.update(name: user.name)).called(3);
    },
  );

  test('keeps results isolated between instances', () async {
    final other = UpdateUserCommand(repository: repository);
    when(() => repository.update(name: user.name))
        .thenAnswer((_) async => const Right(user));
    try {
      await command.execute.runAsync(user.name);
      expect(other.execute.value, isNull);
      expect(other.execute.isRunning.value, isFalse);
    } finally {
      other.dispose();
    }
  });

  test('does not publish a user when disposed during an update', () async {
    final started = Completer<void>();
    final pending = Completer<UpdateRepositoryType>();
    final disposable = UpdateUserCommand(repository: repository);

    when(() => repository.update(name: user.name)).thenAnswer((_) {
      started.complete();
      return pending.future;
    });

    final execution = disposable.execute.runAsync(user.name);
    await started.future;
    disposable.dispose();
    pending.complete(const Right(user));
    expect(await execution, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(disposable.execute.value, isNull);
    expect(disposable.execute.results.value.data, isNull);
    verify(() => repository.update(name: user.name)).called(1);
  });
}
