import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/domain/repositories/interface_user_repository.dart';
import 'package:cordato/features/user/presentation/screens/user/commands/update_avatar_command.dart';

import '../../../../../../support/user/mocks/user_repository_mock.dart';

void main() {
  const seed = 'chosen-avatar';
  const user = UserEntity(
    id: 'user-1',
    avatar: seed,
    name: 'Gabriel',
    status: 'active',
    email: 'person@example.com',
  );

  late UpdateAvatarCommand command;
  late UserRepositoryMock repository;
  void onResult() {}

  setUp(() {
    repository = UserRepositoryMock();
    command = UpdateAvatarCommand(repository: repository);
    command.execute.results.addListener(onResult);
  });

  tearDown(() {
    command.execute.results.removeListener(onResult);
    command.dispose();
  });

  test(
    'starts without a result and saves only the chosen avatar seed',
    () async {
      expect(command.execute.value, isNull);
      when(() => repository.update(avatar: seed))
          .thenAnswer((_) async => const Right(user));

      final data = await command.execute.runAsync(seed);

      expect(data, same(user));
      expect(command.execute.value, same(user));
      expect(command.execute.results.value.data, same(user));
      verify(() => repository.update(avatar: seed)).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  test('preserves avatar validation errors and allows retry', () async {
    const errors = ErrorsEntity(
      errors: [
        ErrorEntity(
          status: '422',
          parameter: 'avatar',
          detail: 'Avatar inválido',
          pointer: '/data/attributes/avatar',
        ),
        ErrorEntity(title: 'Falha adicional'),
      ],
    );
    when(() => repository.update(avatar: seed))
        .thenAnswer((_) async => const Left(errors));

    await expectLater(
      command.execute.runAsync(seed),
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

    when(() => repository.update(avatar: seed))
        .thenAnswer((_) async => const Right(user));

    expect(command.execute.value, same(user));
    expect(command.execute.results.value.hasError, isFalse);
    expect(await command.execute.runAsync(seed), same(user));
  });

  test('prevents duplicate saves while an update is pending', () async {
    final started = Completer<void>();
    final pending = Completer<UpdateRepositoryType>();

    when(() => repository.update(avatar: seed)).thenAnswer((_) {
      started.complete();
      return pending.future;
    });

    final result = command.execute.runAsync(seed);
    await started.future;
    expect(command.execute.isRunning.value, isTrue);

    command.execute.run(seed);
    final joined = command.execute.runAsync('another-avatar');
    expect(joined, same(result));
    verify(() => repository.update(avatar: seed)).called(1);
    pending.complete(const Right(user));

    expect(await result, same(user));
    expect(await joined, same(user));
    expect(command.execute.isRunning.value, isFalse);
    expect(command.execute.results.value.paramData, seed);
    verifyNoMoreInteractions(repository);
  });

  test('disposes execution and loading observables', () async {
    final disposable = UpdateAvatarCommand(repository: repository);
    disposable.dispose();

    await Future<void>.delayed(const Duration(milliseconds: 60));
    void listener() {}

    expect(
      () => disposable.execute.addListener(listener),
      throwsAssertionError,
    );
    expect(
      () => disposable.execute.isRunning.addListener(listener),
      throwsAssertionError,
    );
    verifyZeroInteractions(repository);
  });

  test(
    'delegates seed unchanged and preserves an unmatched response seed',
    () async {
      const input = '  opaque-seed  ';

      when(() => repository.update(avatar: input))
          .thenAnswer((_) async => const Right(user));

      expect(command.execute.results.value.paramData, input);
      expect(command.execute.results.value.data?.avatar, seed);
      expect(await command.execute.runAsync(input), same(user));
      verify(() => repository.update(avatar: input)).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  test('preserves empty typed failure after an avatar was saved', () async {
    when(() => repository.update(avatar: seed))
        .thenAnswer((_) async => const Right(user));
    await command.execute.runAsync(seed);
    const errors = ErrorsEntity(errors: []);

    when(() => repository.update(avatar: seed))
        .thenAnswer((_) async => const Left(errors));

    await expectLater(
      command.execute.runAsync(seed),
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
  });

  test(
    'preserves unexpected repository errors and allows another save',
    () async {
      final failure = StateError('repository unavailable');

      when(() => repository.update(avatar: seed))
          .thenAnswer((_) async => throw failure);

      await expectLater(command.execute.runAsync(seed), throwsA(same(failure)));

      expect(command.execute.results.value.error, same(failure));
      expect(command.execute.errors.value?.error, same(failure));

      when(() => repository.update(avatar: seed))
          .thenAnswer((_) async => const Right(user));

      expect(await command.execute.runAsync(seed), same(user));
    },
  );

  test('keeps avatar saves isolated between instances', () async {
    final other = UpdateAvatarCommand(repository: repository);

    when(() => repository.update(avatar: seed))
        .thenAnswer((_) async => const Right(user));
    try {
      await command.execute.runAsync(seed);
      expect(other.execute.value, isNull);
      expect(other.execute.isRunning.value, isFalse);
    } finally {
      other.dispose();
    }
  });

  test('does not publish an avatar after disposal during save', () async {
    final started = Completer<void>();
    final pending = Completer<UpdateRepositoryType>();
    final disposable = UpdateAvatarCommand(repository: repository);

    when(() => repository.update(avatar: seed)).thenAnswer((_) {
      started.complete();
      return pending.future;
    });

    final execution = disposable.execute.runAsync(seed);
    await started.future;
    disposable.dispose();
    pending.complete(const Right(user));

    expect(await execution, isNull);

    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(disposable.execute.value, isNull);
    expect(disposable.execute.results.value.data, isNull);
    verify(() => repository.update(avatar: seed)).called(1);
  });
}
