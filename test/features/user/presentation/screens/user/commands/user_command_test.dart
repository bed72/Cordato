import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/domain/repositories/interface_user_repository.dart';
import 'package:cordato/features/user/presentation/screens/user/commands/user_command.dart';

import '../../../../../../support/user/mocks/user_repository_mock.dart';

void main() {
  const user = UserEntity(
    id: 'user-1',
    name: 'Nome da API',
    email: 'person@example.com',
    status: 'active',
  );
  const errors = ErrorsEntity(
    errors: [
      ErrorEntity(
        detail: 'Não foi possível identificar o usuário atual.',
        title: 'Usuário indisponível',
        status: '404',
        pointer: '/data/id',
        parameter: 'user',
      ),
    ],
  );
  late UserRepositoryMock repository;
  late UserCommand command;
  void onResult() {}

  setUp(() {
    repository = UserRepositoryMock();
    command = UserCommand(repository: repository);
    command.execute.results.addListener(onResult);
  });

  tearDown(() {
    command.execute.results.removeListener(onResult);
    command.dispose();
  });

  test('loads the user and publishes their name and email', () async {
    when(() => repository.getById()).thenAnswer((_) async => const Right(user));

    expect(command.execute.value, isNull);
    final data = await command.execute.runAsync();

    expect(data, same(user));
    expect(command.execute.value?.name, user.name);
    expect(command.execute.value?.email, user.email);
    expect(command.execute.results.value.data, same(user));
    verify(() => repository.getById()).called(1);
    verifyNoMoreInteractions(repository);
  });

  test('preserves repository errors for the retry state', () async {
    when(() => repository.getById())
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

    expect(command.execute.results.value.hasError, isTrue);
    expect(
      command.execute.errors.value?.error,
      same(command.execute.results.value.error),
    );
    expect(command.execute.value, isNull);
  });

  test('queries the repository again after a failed load', () async {
    when(() => repository.getById())
        .thenAnswer((_) async => const Left(errors));
    await expectLater(
      command.execute.runAsync(),
      throwsA(isA<CommandFailureException>()),
    );
    when(() => repository.getById()).thenAnswer((_) async => const Right(user));

    final data = await command.execute.runAsync();

    expect(data, same(user));
    expect(command.execute.value, same(user));
    verify(() => repository.getById()).called(2);
  });

  test(
    'keeps loading until the repository completes and avoids duplicate queries',
    () async {
      final pending = Completer<GetByIdRepositoryType>();
      final started = Completer<void>();
      when(() => repository.getById()).thenAnswer((_) {
        started.complete();
        return pending.future;
      });

      final data = command.execute.runAsync();
      await started.future;
      expect(command.execute.isRunning.value, isTrue);
      command.execute.run();
      verify(() => repository.getById()).called(1);
      pending.complete(const Right(user));

      expect(await data, same(user));
      expect(command.execute.isRunning.value, isFalse);
      verifyNoMoreInteractions(repository);
    },
  );

  test('exposes unexpected repository exceptions as command errors', () async {
    final failure = StateError('repository unavailable');
    when(() => repository.getById()).thenAnswer((_) async => throw failure);
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

  test(
    'starts with no query and keeps independent instances isolated',
    () async {
      expect(command.execute.value, isNull);
      expect(command.execute.results.value.hasError, isFalse);
      verifyZeroInteractions(repository);
      final other = UserCommand(repository: repository);
      addTearDown(other.dispose);
      when(() => repository.getById())
          .thenAnswer((_) async => const Right(user));

      await command.execute.runAsync();

      expect(other.execute.value, isNull);
      expect(other.execute.isRunning.value, isFalse);
      expect(command.execute.results.value.data, same(user));
    },
  );

  test(
    'preserves an empty typed failure without reusing a previous user',
    () async {
      when(() => repository.getById())
          .thenAnswer((_) async => const Right(user));
      await command.execute.runAsync();
      const emptyErrors = ErrorsEntity(errors: []);
      when(() => repository.getById())
          .thenAnswer((_) async => const Left(emptyErrors));

      await expectLater(
        command.execute.runAsync(),
        throwsA(
          isA<CommandFailureException>().having(
            (failure) => failure.errors,
            'errors',
            same(emptyErrors),
          ),
        ),
      );

      expect(command.execute.value, same(user));
      expect(command.execute.results.value.data, isNull);
      expect(
        command.execute.errors.value?.error,
        same(command.execute.results.value.error),
      );
    },
  );

  test('does not publish a user after disposal during a request', () async {
    final disposable = UserCommand(repository: repository);
    final started = Completer<void>();
    final pending = Completer<GetByIdRepositoryType>();
    when(() => repository.getById()).thenAnswer((_) {
      started.complete();
      return pending.future;
    });
    final execution = disposable.execute.runAsync();
    await started.future;
    disposable.dispose();
    pending.complete(const Right(user));

    expect(await execution, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(disposable.execute.results.value.data, isNull);
    expect(disposable.execute.value, isNull);
    verify(() => repository.getById()).called(1);
  });
}
