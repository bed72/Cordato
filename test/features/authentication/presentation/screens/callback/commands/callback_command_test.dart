import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/domain/enums/email_status_enum.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/commands/callback_command.dart';

import '../../../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  const url = 'https://other.example/confirm?signature=original&expires=123';
  late AuthenticationRepositoryMock repository;
  late CallbackCommand command;
  void onResult() {}

  setUp(() {
    repository = AuthenticationRepositoryMock();
    command = CallbackCommand(repository: repository);
    command.execute.results.addListener(onResult);
  });
  tearDown(() {
    command.execute.results.removeListener(onResult);
    command.dispose();
  });

  test('starts without a result or a confirmation request', () {
    expect(command.execute.value, isNull);
    verifyZeroInteractions(repository);
  });

  for (final status in EmailVerificationStatusEnum.values) {
    test(
      'preserves ${status.name} as confirmation data and delegates the original URL',
      () async {
        when(() => repository.confirmEmail(url))
            .thenAnswer((_) async => status);
        expect(await command.execute.runAsync(url), status);
        expect(command.execute.value, status);
        expect(command.execute.results.value.data, status);
        expect(command.execute.results.value.paramData, url);
        expect(command.execute.results.value.hasError, isFalse);
        verify(() => repository.confirmEmail(url)).called(1);
      },
    );
  }

  test('propagates unexpected confirmation errors', () async {
    final failure = StateError('unexpected');
    when(() => repository.confirmEmail(url))
        .thenAnswer((_) async => throw failure);
    await expectLater(command.execute.runAsync(url), throwsA(same(failure)));
    expect(command.execute.results.value.error, same(failure));
  });

  test(
    'joins pending confirmation without accepting a different URL',
    () async {
      final pending = Completer<EmailVerificationStatusEnum>();
      when(() => repository.confirmEmail(url))
          .thenAnswer((_) => pending.future);
      final execution = command.execute.runAsync(url);
      final joined = command.execute.runAsync('other-url');
      expect(joined, same(execution));
      expect(command.execute.isRunning.value, isTrue);
      pending.complete(.success);
      expect(await execution, EmailVerificationStatusEnum.success);
      expect(await joined, EmailVerificationStatusEnum.success);
      expect(command.execute.results.value.paramData, url);
      verify(() => repository.confirmEmail(url)).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  test('disposal does not publish a pending confirmation', () async {
    final pending = Completer<EmailVerificationStatusEnum>();
    final started = Completer<void>();
    when(() => repository.confirmEmail(url)).thenAnswer((_) {
      started.complete();
      return pending.future;
    });
    final disposable = CallbackCommand(repository: repository);
    final execution = disposable.execute.runAsync(url);
    await started.future;
    disposable.dispose();
    pending.complete(.success);
    expect(await execution, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(disposable.execute.results.value.data, isNull);
  });
}
