import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/commands/delete_expense_command.dart';

import '../../../../../../support/expense/mocks/expense_repository_mock.dart';

void main() {
  late ExpenseRepositoryMock repository;
  late DeleteExpenseCommand command;

  setUp(() {
    repository = ExpenseRepositoryMock();
    command = DeleteExpenseCommand(repository: repository);
  });

  tearDown(() => command.dispose());

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

        expect(result, same(response));
        expect(command.execute.value, same(response));
        expect(result?.right, deleted);
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
        ),
        ErrorEntity(title: 'Outro erro'),
      ],
    );
    const response = Left<ErrorsEntity, bool>(errors);
    when(() => repository.delete(id: '1')).thenAnswer((_) async => response);

    final result = await command.execute.runAsync('1');

    expect(result, same(response));
    expect(command.execute.value, same(response));
    expect(result?.left, same(errors));
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

    expect((await result)?.right, isTrue);
    expect(command.execute.isRunning.value, isFalse);
    verifyNoMoreInteractions(repository);
  });

  test('allows retry after a repository error', () async {
    final errors = ErrorsEntity.unknown();
    when(() => repository.delete(id: '1'))
        .thenAnswer((_) async => Left(errors));

    expect((await command.execute.runAsync('1'))?.left, same(errors));
    when(() => repository.delete(id: '1'))
        .thenAnswer((_) async => const Right(true));

    expect((await command.execute.runAsync('1'))?.right, isTrue);
    expect(command.execute.value?.right, isTrue);
    verify(() => repository.delete(id: '1')).called(2);
    verifyNoMoreInteractions(repository);
  });

  test('allows retry after an unconfirmed deletion', () async {
    when(() => repository.delete(id: '1'))
        .thenAnswer((_) async => const Right(false));

    expect((await command.execute.runAsync('1'))?.right, isFalse);
    when(() => repository.delete(id: '1'))
        .thenAnswer((_) async => const Right(true));

    expect((await command.execute.runAsync('1'))?.right, isTrue);
    verify(() => repository.delete(id: '1')).called(2);
  });

  test('deletes another expense and replaces the previous result', () async {
    when(() => repository.delete(id: '1'))
        .thenAnswer((_) async => const Right(true));
    when(() => repository.delete(id: '2'))
        .thenAnswer((_) async => const Right(false));

    await command.execute.runAsync('1');
    final result = await command.execute.runAsync('2');

    expect(result?.right, isFalse);
    expect(command.execute.value?.right, isFalse);
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

      expect(command.execute.value?.right, isTrue);
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
    void onResult() {}
    command.execute.results.addListener(onResult);
    try {
      await expectLater(command.execute.runAsync('1'), throwsA(same(failure)));
    } finally {
      command.execute.results.removeListener(onResult);
    }
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
