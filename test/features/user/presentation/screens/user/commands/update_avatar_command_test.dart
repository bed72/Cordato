import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
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

  setUp(() {
    repository = UserRepositoryMock();
    command = UpdateAvatarCommand(repository: repository);
  });
  tearDown(() => command.dispose());

  test(
    'starts without a result and saves only the chosen avatar seed',
    () async {
      expect(command.execute.value, isNull);
      when(() => repository.update(avatar: seed))
          .thenAnswer((_) async => const Right(user));
      final result = await command.execute.runAsync(seed);
      expect(result?.right, same(user));
      expect(command.execute.value?.right, same(user));
      verify(() => repository.update(avatar: seed)).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  test('preserves avatar validation errors and allows retry', () async {
    const errors = ErrorsEntity(
      errors: [
        ErrorEntity(
          detail: 'Avatar inválido',
          pointer: '/data/attributes/avatar',
        ),
      ],
    );
    when(() => repository.update(avatar: seed))
        .thenAnswer((_) async => const Left(errors));
    expect((await command.execute.runAsync(seed))?.left, same(errors));
    expect(command.execute.value?.left, same(errors));
    when(() => repository.update(avatar: seed))
        .thenAnswer((_) async => const Right(user));
    expect((await command.execute.runAsync(seed))?.right, same(user));
    expect(command.execute.value?.right, same(user));
  });

  test('prevents duplicate saves while an update is pending', () async {
    final pending = Completer<UpdateRepositoryType>();
    final started = Completer<void>();
    when(() => repository.update(avatar: seed)).thenAnswer((_) {
      started.complete();
      return pending.future;
    });

    final result = command.execute.runAsync(seed);
    await started.future;
    expect(command.execute.isRunning.value, isTrue);

    command.execute.run(seed);
    verify(() => repository.update(avatar: seed)).called(1);
    pending.complete(const Right(user));

    expect((await result)?.right, same(user));
    expect(command.execute.isRunning.value, isFalse);
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
}
