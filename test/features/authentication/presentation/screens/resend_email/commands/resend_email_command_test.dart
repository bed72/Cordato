import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/commands/resend_email_command.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import '../../../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  const email = ' Person@Example.com ';
  late AuthenticationRepositoryMock repository;
  late ResendEmailCommand command;
  void onResult() {}

  setUp(() {
    repository = AuthenticationRepositoryMock();
    command = ResendEmailCommand(repository: repository);
    command.execute.results.addListener(onResult);
  });
  tearDown(() {
    command.execute.results.removeListener(onResult);
    command.dispose();
  });

  test('starts without acceptance or a repository call', () {
    expect(command.execute.value, isNull);
    verifyZeroInteractions(repository);
  });

  test('delegates the email unchanged and publishes completion', () async {
    when(() => repository.resendEmail(email: email)).thenAnswer((_) async {});
    expect(await command.execute.runAsync(email), isTrue);
    expect(command.execute.value, isTrue);
    expect(command.execute.results.value.data, isTrue);
    expect(command.execute.results.value.paramData, email);
    verify(() => repository.resendEmail(email: email)).called(1);
  });

  for (final errors in [
    const ErrorsEntity(errors: []),
    const ErrorsEntity(
      errors: [
        ErrorEntity(
          status: '429',
          title: 'Aguarde',
          detail: 'Tente novamente.',
          pointer: '/email',
          parameter: 'email',
        ),
        ErrorEntity(),
      ],
    ),
  ]) {
    test(
      'preserves ${errors.errors.length} typed errors without reusing previous acceptance',
      () async {
        when(() => repository.resendEmail(email: email))
            .thenAnswer((_) async {});
        await command.execute.runAsync(email);
        when(() => repository.resendEmail(email: email)).thenAnswer(
          (_) async => throw AuthenticationException(errors: errors),
        );
        await expectLater(
          command.execute.runAsync(email),
          throwsA(
            isA<CommandFailureException>().having(
              (failure) => failure.errors,
              'errors',
              same(errors),
            ),
          ),
        );
        expect(command.execute.results.value.data, isNull);
        expect(command.execute.results.value.hasError, isTrue);
        expect(
          (command.execute.results.value.error as CommandFailureException)
              .errors,
          same(errors),
        );
        when(() => repository.resendEmail(email: email))
            .thenAnswer((_) async {});
        expect(await command.execute.runAsync(email), isTrue);
        expect(command.execute.results.value.hasError, isFalse);
      },
    );
  }

  test('exposes unexpected repository errors unchanged', () async {
    final failure = StateError('unexpected');
    when(() => repository.resendEmail(email: email))
        .thenAnswer((_) async => throw failure);
    await expectLater(command.execute.runAsync(email), throwsA(same(failure)));
    expect(command.execute.results.value.error, same(failure));
  });

  test('waits for completion and joins occupied resend without requesting another email', () async {
    final pending = Completer<void>();
    when(() => repository.resendEmail(email: email))
        .thenAnswer((_) => pending.future);
    final execution = command.execute.runAsync(email);
    final joined = command.execute.runAsync('other@example.com');
    expect(joined, same(execution));
    expect(command.execute.isRunning.value, isTrue);
    expect(command.execute.value, isNull);
    pending.complete();
    expect(await execution, isTrue);
    expect(await joined, isTrue);
    expect(command.execute.results.value.paramData, email);
    verify(() => repository.resendEmail(email: email)).called(1);
    verifyNoMoreInteractions(repository);
  });

  test('disposal prevents publishing a pending resend', () async {
    final pending = Completer<void>();
    final started = Completer<void>();
    when(() => repository.resendEmail(email: email)).thenAnswer((_) {
      started.complete();
      return pending.future;
    });
    final disposable = ResendEmailCommand(repository: repository);
    final execution = disposable.execute.runAsync(email);
    await started.future;
    disposable.dispose();
    pending.complete();
    expect(await execution, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(disposable.execute.results.value.data, isNull);
  });
}
