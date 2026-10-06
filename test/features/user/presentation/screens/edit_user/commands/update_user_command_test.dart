import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/domain/repositories/interface_user_repository.dart';
import 'package:cordato/features/user/presentation/screens/edit_user/commands/update_user_command.dart';

import '../../../../../../support/user/mocks/user_repository_mock.dart';

void main() {
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
  });

  tearDown(() => command.dispose());

  test('updates the current user and publishes the API result', () async {
    when(() => repository.update(name: user.name))
        .thenAnswer((_) async => const Right(user));

    final response = await command.execute.runAsync(user.name);

    expect(response?.right, same(user));
    expect(command.execute.value?.right, same(user));
    verify(() => repository.update(name: user.name)).called(1);
    verifyNoMoreInteractions(repository);
  });

  test('preserves validation errors for presentation feedback', () async {
    const errors = ErrorsEntity(
      errors: [
        ErrorEntity(
          status: '422',
          detail: 'Informe um nome válido.',
          pointer: '/data/attributes/name',
        ),
      ],
    );
    when(() => repository.update(name: user.name))
        .thenAnswer((_) async => const Left(errors));

    final response = await command.execute.runAsync(user.name);

    expect(response?.left, same(errors));
    expect(command.execute.value?.left, same(errors));
  });

  test('prevents additional updates while a request is pending', () async {
    final pending = Completer<UpdateRepositoryType>();
    final started = Completer<void>();
    when(() => repository.update(name: user.name)).thenAnswer((_) {
      started.complete();
      return pending.future;
    });

    final response = command.execute.runAsync(user.name);
    await started.future;
    expect(command.execute.isRunning.value, isTrue);
    command.execute.run(user.name);
    verify(() => repository.update(name: user.name)).called(1);
    pending.complete(const Right(user));

    expect((await response)?.right, same(user));
    expect(command.execute.isRunning.value, isFalse);
    verifyNoMoreInteractions(repository);
  });

  test('exposes unexpected repository exceptions as command errors', () async {
    final failure = StateError('repository unavailable');
    when(() => repository.update(name: user.name))
        .thenAnswer((_) async => throw failure);
    void onResult() {}
    command.execute.results.addListener(onResult);
    try {
      await expectLater(
        command.execute.runAsync(user.name),
        throwsA(same(failure)),
      );
    } finally {
      command.execute.results.removeListener(onResult);
    }
  });
}
