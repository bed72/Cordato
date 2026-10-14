import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/commands/delete_expense_command.dart';

import '../../../../../../support/expense/mocks/expense_repository_mock.dart';

void main() {
  void onResult() {}
  late ExpenseRepositoryMock repository;
  late DeleteExpenseCommand command;

  setUp(() {
    repository = ExpenseRepositoryMock();
    command = DeleteExpenseCommand(repository: repository);
    command.execute.results.addListener(onResult);
  });

  tearDown(() {
    command.execute.results.removeListener(onResult);
    command.dispose();
  });

  test('waits for execution before deleting an expense', () {
    expect(command.execute.value, isNull);
    expect(command.execute.isRunning.value, isFalse);
    verifyZeroInteractions(repository);
  });

  for (final deleted in [true, false]) {
    test(
      'delegates the unchanged id and preserves deletion result $deleted',
      () async {
        const id = 'a/b?c#d';
        final response = Right<ErrorsEntity, bool>(deleted);
        when(() => repository.delete(id: id)).thenAnswer((_) async => response);

        final result = await command.execute.runAsync(id);

        expect(result, deleted);
        expect(command.execute.value, deleted);
        expect(command.execute.results.value.data, deleted);
        expect(command.execute.results.value.hasError, isFalse);
        verify(() => repository.delete(id: id)).called(1);
        verifyNoMoreInteractions(repository);
      },
    );
  }

  test('preserves repository errors for presentation feedback', () async {
    const errors = ErrorsEntity(
      errors: [
        ErrorEntity(
          status: '403',
          title: 'Acesso negado',
          detail: 'Sem permissão para excluir a despesa.',
          pointer: '/data/id',
          parameter: 'id',
        ),
        ErrorEntity(title: 'Outro erro'),
      ],
    );
    const response = Left<ErrorsEntity, bool>(errors);
    when(() => repository.delete(id: '1')).thenAnswer((_) async => response);

    await expectLater(
      command.execute.runAsync('1'),
      throwsA(
        isA<CommandFailureException>().having(
          (failure) => failure.errors,
          'errors',
          same(errors),
        ),
      ),
    );
    final snapshot = command.execute.results.value;
    expect(snapshot.hasError, isTrue);
    expect(snapshot.data, isNull);
    expect((snapshot.error as CommandFailureException).errors, same(errors));
    expect(command.execute.errors.value?.error, same(snapshot.error));
    verify(() => repository.delete(id: '1')).called(1);
    verifyNoMoreInteractions(repository);
  });

  test('prevents additional deletion while a request is pending', () async {
    final started = Completer<void>();
    final pending = Completer<DeleteRepositoryType>();
    when(() => repository.delete(id: '1')).thenAnswer((_) {
      started.complete();
      return pending.future;
    });

    final result = command.execute.runAsync('1');
    await started.future;
    expect(command.execute.isRunning.value, isTrue);
    command.execute.run('2');
    verify(() => repository.delete(id: '1')).called(1);
    pending.complete(const Right(true));

    expect(await result, isTrue);
    expect(command.execute.isRunning.value, isFalse);
    verifyNoMoreInteractions(repository);
  });

  test('allows retry after a repository error', () async {
    final errors = ErrorsEntity.unknown();
    when(() => repository.delete(id: '1'))
        .thenAnswer((_) async => Left(errors));

    await expectLater(
      command.execute.runAsync('1'),
      throwsA(isA<CommandFailureException>()),
    );
    when(() => repository.delete(id: '1'))
        .thenAnswer((_) async => const Right(true));

    expect(await command.execute.runAsync('1'), isTrue);
    expect(command.execute.value, isTrue);
    expect(command.execute.errors.value, isNull);
    expect(command.execute.results.value.hasError, isFalse);
    verify(() => repository.delete(id: '1')).called(2);
    verifyNoMoreInteractions(repository);
  });

  test('allows retry after an unconfirmed deletion', () async {
    when(() => repository.delete(id: '1'))
        .thenAnswer((_) async => const Right(false));

    expect(await command.execute.runAsync('1'), isFalse);
    when(() => repository.delete(id: '1'))
        .thenAnswer((_) async => const Right(true));

    expect(await command.execute.runAsync('1'), isTrue);
    verify(() => repository.delete(id: '1')).called(2);
  });

  test('deletes another expense and replaces the previous result', () async {
    when(() => repository.delete(id: '1'))
        .thenAnswer((_) async => const Right(true));
    when(() => repository.delete(id: '2'))
        .thenAnswer((_) async => const Right(false));

    await command.execute.runAsync('1');
    final result = await command.execute.runAsync('2');

    expect(result, isFalse);
    expect(command.execute.value, isFalse);
    verify(() => repository.delete(id: '1')).called(1);
    verify(() => repository.delete(id: '2')).called(1);
    verifyNoMoreInteractions(repository);
  });

  test('keeps deletion state isolated between command instances', () async {
    final otherCommand = DeleteExpenseCommand(repository: repository);
    when(() => repository.delete(id: '1'))
        .thenAnswer((_) async => const Right(true));
    try {
      await command.execute.runAsync('1');

      expect(command.execute.value, isTrue);
      expect(otherCommand.execute.value, isNull);
      expect(otherCommand.execute.isRunning.value, isFalse);
    } finally {
      otherCommand.dispose();
    }
  });

  test('exposes unexpected repository exceptions as command errors', () async {
    final failure = StateError('repository unavailable');
    when(() => repository.delete(id: '1'))
        .thenAnswer((_) async => throw failure);
    await expectLater(command.execute.runAsync('1'), throwsA(same(failure)));
    expect(command.execute.results.value.error, same(failure));
    expect(command.execute.errors.value?.error, same(failure));
  });

  test(
    'does not confirm deletion using old success after an empty failure',
    () async {
      when(() => repository.delete(id: '1'))
          .thenAnswer((_) async => const Right(true));
      await command.execute.runAsync('1');
      const errors = ErrorsEntity(errors: []);
      when(() => repository.delete(id: '2'))
          .thenAnswer((_) async => const Left(errors));
      await expectLater(
        command.execute.runAsync('2'),
        throwsA(
          isA<CommandFailureException>().having(
            (failure) => failure.errors,
            'errors',
            same(errors),
          ),
        ),
      );
      expect(command.execute.value, isTrue);
      expect(command.execute.results.value.data, isNull);
      expect(command.execute.results.value.paramData, '2');
      expect(command.execute.results.value.hasError, isTrue);
    },
  );

  test('does not publish deletion after disposal while pending', () async {
    final disposable = DeleteExpenseCommand(repository: repository);
    final pending = Completer<DeleteRepositoryType>();
    final started = Completer<void>();
    when(() => repository.delete(id: '1')).thenAnswer((_) {
      started.complete();
      return pending.future;
    });
    final execution = disposable.execute.runAsync('1');
    await started.future;
    disposable.dispose();
    pending.complete(const Right(true));
    expect(await execution, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(disposable.execute.results.value.data, isNull);
    expect(disposable.execute.results.value.isRunning, isTrue);
  });

  test('disposes the observable execution and its loading state', () async {
    final disposable = DeleteExpenseCommand(repository: repository);
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
