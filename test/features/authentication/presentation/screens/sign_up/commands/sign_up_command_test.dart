import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/commands/sign_up_command.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import '../../../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  const input = (email: ' Person@Example.com ', password: ' secret ');
  late AuthenticationRepositoryMock repository;
  late SignUpCommand command;
  void onResult() {}

  setUp(() {
    repository = AuthenticationRepositoryMock();
    command = SignUpCommand(repository: repository);
    command.execute.results.addListener(onResult);
  });
  tearDown(() {
    command.execute.results.removeListener(onResult);
    command.dispose();
  });

  test('starts without a result or a repository call', () {
    expect(command.execute.value, isNull);
    verifyZeroInteractions(repository);
  });

  test('delegates credentials unchanged and publishes completion', () async {
    when(() => repository.signUp(email: input.email, password: input.password))
        .thenAnswer((_) async {});
    expect(await command.execute.runAsync(input), isTrue);
    expect(command.execute.value, isTrue);
    expect(command.execute.results.value.data, isTrue);
    expect(command.execute.results.value.paramData, input);
    verify(
      () => repository.signUp(email: input.email, password: input.password),
    ).called(1);
  });

  for (final errors in [
    const ErrorsEntity(errors: []),
    const ErrorsEntity(
      errors: [
        ErrorEntity(
          title: 'Validação',
          status: '422',
          pointer: '/data/attributes/email',
          parameter: 'email',
        ),
        ErrorEntity(detail: 'Outra falha'),
      ],
    ),
  ]) {
    test(
      'preserves ${errors.errors.length} typed errors after a previous success and allows retry',
      () async {
        when(
          () => repository.signUp(email: input.email, password: input.password),
        ).thenAnswer((_) async {});
        await command.execute.runAsync(input);
        when(
          () => repository.signUp(email: input.email, password: input.password),
        ).thenAnswer(
          (_) async => throw AuthenticationException(errors: errors),
        );
        await expectLater(
          command.execute.runAsync(input),
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
        expect(command.execute.value, isTrue);
        expect(
          (command.execute.results.value.error as CommandFailureException)
              .errors,
          same(errors),
        );
        when(
          () => repository.signUp(email: input.email, password: input.password),
        ).thenAnswer((_) async {});
        expect(await command.execute.runAsync(input), isTrue);
        expect(command.execute.results.value.hasError, isFalse);
      },
    );
  }

  test('exposes unexpected repository errors unchanged', () async {
    final failure = StateError('unexpected');
    when(() => repository.signUp(email: input.email, password: input.password))
        .thenAnswer((_) async => throw failure);
    await expectLater(command.execute.runAsync(input), throwsA(same(failure)));
    expect(command.execute.results.value.error, same(failure));
  });

  test('waits for completion and joins occupied execution without submitting another input', () async {
    final pending = Completer<void>();
    when(() => repository.signUp(email: input.email, password: input.password))
        .thenAnswer((_) => pending.future);
    final execution = command.execute.runAsync(input);
    final joined = command.execute.runAsync((
      email: 'other@example.com',
      password: 'other',
    ));
    expect(joined, same(execution));
    expect(command.execute.isRunning.value, isTrue);
    expect(command.execute.value, isNull);
    pending.complete();
    expect(await execution, isTrue);
    expect(await joined, isTrue);
    expect(command.execute.results.value.paramData, input);
    verify(
      () => repository.signUp(email: input.email, password: input.password),
    ).called(1);
    verifyNoMoreInteractions(repository);
  });

  test('disposal prevents publishing a pending registration', () async {
    final pending = Completer<void>();
    final started = Completer<void>();
    when(() => repository.signUp(email: input.email, password: input.password))
        .thenAnswer((_) {
          started.complete();
          return pending.future;
        });
    final disposable = SignUpCommand(repository: repository);
    final execution = disposable.execute.runAsync(input);
    await started.future;
    disposable.dispose();
    pending.complete();
    expect(await execution, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(disposable.execute.results.value.data, isNull);
  });
}
