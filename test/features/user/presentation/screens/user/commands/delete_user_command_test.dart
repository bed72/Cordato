import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/user/domain/repositories/interface_user_repository.dart';
import 'package:cordato/features/user/presentation/screens/user/commands/delete_user_command.dart';

import '../../../../../../support/user/mocks/user_repository_mock.dart';

void main() {
  late IUserRepository repository;
  late DeleteUserCommand command;

  setUp(() {
    repository = UserRepositoryMock();
    command = DeleteUserCommand(repository: repository);
  });

  tearDown(() => command.dispose());

  test('deletes the current user and publishes confirmation', () async {
    when(() => repository.delete()).thenAnswer((_) async => const Right(true));

    expect(command.execute.value, isNull);
    final result = await command.execute.runAsync();

    expect(result?.right, isTrue);
    expect(command.execute.value?.right, isTrue);
    verify(() => repository.delete()).called(1);
  });

  test('preserves an unconfirmed deletion without reporting success', () async {
    when(() => repository.delete()).thenAnswer((_) async => const Right(false));

    final result = await command.execute.runAsync();

    expect(result?.right, isFalse);
    expect(command.execute.value?.right, isFalse);
  });

  test('preserves API errors for presentation feedback', () async {
    const errors = ErrorsEntity(
      errors: [
        ErrorEntity(
          status: '403',
          title: 'Não autorizado',
          detail: 'Não foi possível apagar a conta.',
        ),
      ],
    );
    when(() => repository.delete()).thenAnswer((_) async => const Left(errors));

    final result = await command.execute.runAsync();

    expect(result?.left, same(errors));
    expect(command.execute.value?.left, same(errors));
  });

  test('prevents additional deletion while a request is pending', () async {
    final pending = Completer<DeleteRepositoryType>();
    when(() => repository.delete()).thenAnswer((_) => pending.future);

    final result = command.execute.runAsync();
    await Future<void>.delayed(Duration.zero);
    expect(command.execute.isRunning.value, isTrue);
    command.execute.run();
    verify(() => repository.delete()).called(1);
    pending.complete(const Right(true));

    expect((await result)?.right, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(command.execute.isRunning.value, isFalse);
    verifyNoMoreInteractions(repository);
  });

  test('allows another attempt after a failed deletion', () async {
    when(() => repository.delete()).thenAnswer((_) async => const Right(false));
    await command.execute.runAsync();
    when(() => repository.delete()).thenAnswer((_) async => const Right(true));

    expect((await command.execute.runAsync())?.right, isTrue);
    verify(() => repository.delete()).called(2);
  });

  test('exposes unexpected repository exceptions as command errors', () async {
    final failure = StateError('repository unavailable');
    when(() => repository.delete()).thenAnswer((_) async => throw failure);

    void onResult() {}
    command.execute.results.addListener(onResult);
    try {
      await expectLater(command.execute.runAsync(), throwsA(same(failure)));
    } finally {
      command.execute.results.removeListener(onResult);
    }
  });
}
