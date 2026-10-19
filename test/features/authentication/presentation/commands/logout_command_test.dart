import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/presentation/commands/logout_command.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import '../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  late AuthenticationRepositoryMock repository;
  late LogoutCommand command;
  void onResult() {}

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
    verifyZeroInteractions(repository);
  });

  test('publishes true after repository logout completes', () async {
    when(() => repository.logout()).thenAnswer((_) async {});
    expect(await command.execute.runAsync(), isTrue);
    expect(command.execute.value, isTrue);
    expect(command.execute.results.value.data, isTrue);
    verify(() => repository.logout()).called(1);
  });

  for (final errors in [
    const ErrorsEntity(errors: []),
    const ErrorsEntity(
      errors: [
        ErrorEntity(
          status: '403',
          title: 'Não autorizado',
          pointer: '/status',
          parameter: 'status',
        ),
        ErrorEntity(detail: 'Outra falha'),
      ],
    ),
  ]) {
    test(
      'preserves ${errors.errors.length} typed errors after prior logout and allows retry',
      () async {
        when(() => repository.logout()).thenAnswer((_) async {});
        await command.execute.runAsync();
        when(() => repository.logout()).thenAnswer(
          (_) async => throw AuthenticationException(errors: errors),
        );
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
        expect(command.execute.results.value.data, isNull);
        expect(
          (command.execute.results.value.error as CommandFailureException)
              .errors,
          same(errors),
        );
        when(() => repository.logout()).thenAnswer((_) async {});
        expect(await command.execute.runAsync(), isTrue);
        expect(command.execute.results.value.hasError, isFalse);
      },
    );
  }

  test('exposes unexpected repository errors unchanged', () async {
    final failure = StateError('unexpected');
    when(() => repository.logout()).thenAnswer((_) async => throw failure);
    await expectLater(command.execute.runAsync(), throwsA(same(failure)));
    expect(command.execute.results.value.error, same(failure));
  });

  test(
    'does not confirm logout or start another request while pending',
    () async {
      final pending = Completer<void>();
      when(() => repository.logout()).thenAnswer((_) => pending.future);
      final execution = command.execute.runAsync();
      final joined = command.execute.runAsync();
      expect(joined, same(execution));
      expect(command.execute.isRunning.value, isTrue);
      expect(command.execute.value, isNull);
      pending.complete();
      expect(await execution, isTrue);
      expect(await joined, isTrue);
      verify(() => repository.logout()).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  test('keeps separate command instances isolated', () async {
    final other = LogoutCommand(repository: repository);
    addTearDown(other.dispose);
    when(() => repository.logout()).thenAnswer((_) async {});
    await command.execute.runAsync();
    expect(other.execute.value, isNull);
    expect(other.execute.results.value.data, isNull);
  });

  test('disposal prevents publishing a pending logout', () async {
    final pending = Completer<void>();
    final started = Completer<void>();
    when(() => repository.logout()).thenAnswer((_) {
      started.complete();
      return pending.future;
    });
    final disposable = LogoutCommand(repository: repository);
    final execution = disposable.execute.runAsync();
    await started.future;
    disposable.dispose();
    pending.complete();
    expect(await execution, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(disposable.execute.results.value.data, isNull);
  });
}
