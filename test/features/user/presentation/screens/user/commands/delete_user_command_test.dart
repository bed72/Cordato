import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import 'package:cordato/features/user/domain/repositories/interface_user_repository.dart';
import 'package:cordato/features/user/presentation/screens/user/commands/delete_user_command.dart';

import '../../../../../../support/user/mocks/user_repository_mock.dart';

void main() {
  void onResult() {}
  late DeleteUserCommand command;
  late IUserRepository repository;

  setUp(() {
    repository = UserRepositoryMock();
    command = DeleteUserCommand(repository: repository);
    command.execute.results.addListener(onResult);
  });

  tearDown(() {
    command.execute.results.removeListener(onResult);
    command.dispose();
  });

  test('deletes the current user and publishes confirmation', () async {
    when(() => repository.delete()).thenAnswer((_) async => const Right(true));

    expect(command.execute.value, isNull);
    final data = await command.execute.runAsync();

    expect(data, isTrue);
    expect(command.execute.value, isTrue);
    expect(command.execute.results.value.data, isTrue);
    verify(() => repository.delete()).called(1);
  });

  test('preserves an unconfirmed deletion without reporting success', () async {
    when(() => repository.delete()).thenAnswer((_) async => const Right(false));

    final data = await command.execute.runAsync();

    expect(data, isFalse);
    expect(command.execute.value, isFalse);
    expect(command.execute.results.value.data, isFalse);
    expect(command.execute.results.value.hasError, isFalse);
  });

  test('preserves API errors for presentation feedback', () async {
    const errors = ErrorsEntity(
      errors: [
        ErrorEntity(
          status: '403',
          title: 'Não autorizado',
          detail: 'Não foi possível apagar a conta.',
          pointer: '/data/id',
          parameter: 'id',
        ),
        ErrorEntity(title: 'Falha adicional'),
      ],
    );
    when(() => repository.delete()).thenAnswer((_) async => const Left(errors));

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

  test('prevents additional deletion while a request is pending', () async {
    final pending = Completer<DeleteRepositoryType>();
    when(() => repository.delete()).thenAnswer((_) => pending.future);

    final data = command.execute.runAsync();
    await Future<void>.delayed(Duration.zero);
    expect(command.execute.isRunning.value, isTrue);

    command.execute.run();
    final joined = command.execute.runAsync();

    expect(joined, same(data));

    verify(() => repository.delete()).called(1);
    pending.complete(const Right(true));

    expect(await data, isTrue);
    expect(await joined, isTrue);

    await Future<void>.delayed(Duration.zero);

    expect(command.execute.isRunning.value, isFalse);
    verifyNoMoreInteractions(repository);
  });

  test('allows another attempt after a failed deletion', () async {
    when(() => repository.delete()).thenAnswer((_) async => const Right(false));
    await command.execute.runAsync();
    when(() => repository.delete()).thenAnswer((_) async => const Right(true));

    expect(await command.execute.runAsync(), isTrue);
    verify(() => repository.delete()).called(2);
  });

  test('exposes unexpected repository exceptions as command errors', () async {
    final failure = StateError('repository unavailable');
    when(() => repository.delete()).thenAnswer((_) async => throw failure);

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
    'keeps empty failure separate from previous confirmation and allows retry',
    () async {
      when(() => repository.delete())
          .thenAnswer((_) async => const Right(true));
      await command.execute.runAsync();
      const errors = ErrorsEntity(errors: []);
      when(() => repository.delete())
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
      expect(
        command.execute.errors.value?.error,
        same(command.execute.results.value.error),
      );
      when(() => repository.delete())
          .thenAnswer((_) async => const Right(true));
      expect(await command.execute.runAsync(), isTrue);
      expect(command.execute.results.value.hasError, isFalse);
      verify(() => repository.delete()).called(3);
    },
  );

  test('keeps deletion state isolated between instances', () async {
    final other = DeleteUserCommand(repository: repository);
    when(() => repository.delete()).thenAnswer((_) async => const Right(true));
    try {
      await command.execute.runAsync();
      expect(other.execute.value, isNull);
      expect(other.execute.isRunning.value, isFalse);
    } finally {
      other.dispose();
    }
  });

  test('does not publish confirmation when disposed during deletion', () async {
    final started = Completer<void>();
    final pending = Completer<DeleteRepositoryType>();
    final disposable = DeleteUserCommand(repository: repository);

    when(() => repository.delete()).thenAnswer((_) {
      started.complete();
      return pending.future;
    });

    final execution = disposable.execute.runAsync();

    await started.future;
    disposable.dispose();
    pending.complete(const Right(true));

    expect(await execution, isNull);

    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(disposable.execute.value, isNull);
    expect(disposable.execute.results.value.data, isNull);
    verify(() => repository.delete()).called(1);
  });
}
