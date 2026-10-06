import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
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
      ErrorEntity(detail: 'Não foi possível identificar o usuário atual.'),
    ],
  );
  late UserRepositoryMock repository;
  late UserCommand command;

  setUp(() {
    repository = UserRepositoryMock();
    command = UserCommand(repository: repository);
  });

  tearDown(() => command.dispose());

  test('loads the user and publishes their name and email', () async {
    when(() => repository.getById()).thenAnswer((_) async => const Right(user));

    expect(command.execute.value, isNull);
    final result = await command.execute.runAsync();

    expect(result?.right, same(user));
    expect(command.execute.value?.right.name, user.name);
    expect(command.execute.value?.right.email, user.email);
    verify(() => repository.getById()).called(1);
    verifyNoMoreInteractions(repository);
  });

  test('preserves repository errors for the retry state', () async {
    when(() => repository.getById())
        .thenAnswer((_) async => const Left(errors));

    final result = await command.execute.runAsync();

    expect(result?.left, same(errors));
    expect(command.execute.value?.left, same(errors));
  });

  test('queries the repository again after a failed load', () async {
    when(() => repository.getById())
        .thenAnswer((_) async => const Left(errors));
    await command.execute.runAsync();
    when(() => repository.getById()).thenAnswer((_) async => const Right(user));

    final result = await command.execute.runAsync();

    expect(result?.right, same(user));
    expect(command.execute.value?.right, same(user));
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

      final result = command.execute.runAsync();
      await started.future;
      expect(command.execute.isRunning.value, isTrue);
      command.execute.run();
      verify(() => repository.getById()).called(1);
      pending.complete(const Right(user));

      expect((await result)?.right, same(user));
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
    } finally {
      command.execute.results.removeListener(onResult);
    }
  });
}
