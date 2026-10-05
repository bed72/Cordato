import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';
import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/authentication/presentation/commands/logout_command.dart';

import '../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  late IAuthenticationRepository repository;
  late LogoutCommand command;

  setUp(() {
    repository = AuthenticationRepositoryMock();
    command = LogoutCommand(repository: repository);
  });

  tearDown(() => command.dispose());

  test('delegates logout and publishes repository success', () async {
    when(() => repository.logout()).thenAnswer((_) async => const Right(true));

    expect(command.execute.value, isNull);
    final result = await command.execute.runAsync();

    expect(result?.right, isTrue);
    expect(command.execute.value?.right, isTrue);
    verify(() => repository.logout()).called(1);
  });

  test('preserves repository errors as a command result', () async {
    const errors = ErrorsEntity(
      errors: [
        ErrorEntity(
          status: '403',
          title: 'Não autorizado',
          detail: 'Conta bloqueada.',
        ),
      ],
    );
    when(() => repository.logout()).thenAnswer((_) async => const Left(errors));

    final result = await command.execute.runAsync();

    expect(result?.left, same(errors));
    expect(command.execute.value?.left, same(errors));
  });

  test('prevents additional execution while logout is pending', () async {
    final pending = Completer<LogoutRepositoryType>();
    when(() => repository.logout()).thenAnswer((_) => pending.future);

    final result = command.execute.runAsync();
    await Future<void>.delayed(Duration.zero);
    expect(command.execute.isRunning.value, isTrue);
    command.execute.run();
    verify(() => repository.logout()).called(1);
    pending.complete(const Right(true));

    expect((await result)?.right, isTrue);
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
    } finally {
      command.execute.results.removeListener(onResult);
    }
  });
}
