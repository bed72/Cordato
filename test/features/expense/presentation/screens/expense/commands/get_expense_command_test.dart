import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';
import 'package:cordato/features/expense/presentation/screens/expense/commands/get_expense_command.dart';

import '../../../../../../support/expense/mocks/expense_repository_mock.dart';

void main() {
  late ExpenseRepositoryMock repository;
  late GetExpenseCommand command;
  late ExpenseEntity entity;
  setUp(() {
    repository = ExpenseRepositoryMock();
    command = GetExpenseCommand(repository: repository);
    entity = ExpenseEntity(
      id: '8',
      cents: .create(cents: 1500).right,
      description: 'Ônibus e metrô',
      occurredOn: DateTime(2026, 10, 5),
      category: .other,
    );
  });
  tearDown(() => command.dispose());
  test('waits for execution before fetching an expense', () {
    expect(command.execute.value, isNull);
    expect(command.execute.isRunning.value, isFalse);
    verifyZeroInteractions(repository);
  });
  test(
    'delegates the unchanged id and preserves the repository result',
    () async {
      final GetByIdRepositoryType response = Right(entity);
      when(() => repository.getById(id: 'a/b?c#d'))
          .thenAnswer((_) async => response);
      expect(await command.execute.runAsync('a/b?c#d'), same(response));
      expect(command.execute.value, same(response));
      verify(() => repository.getById(id: 'a/b?c#d')).called(1);
      verifyNoMoreInteractions(repository);
    },
  );
  test('preserves domain errors for the retry state', () async {
    const errors = ErrorsEntity(
      errors: [
        ErrorEntity(
          title: 'Despesa não encontrada',
          status: '404',
          pointer: '/data/id',
        ),
      ],
    );
    const GetByIdRepositoryType response = Left(errors);
    when(() => repository.getById(id: '8')).thenAnswer((_) async => response);
    expect(await command.execute.runAsync('8'), same(response));
    expect(command.execute.value?.left, same(errors));
  });
  test('blocks repeated fetches while the request is pending', () async {
    final started = Completer<void>();
    final pending = Completer<GetByIdRepositoryType>();
    when(() => repository.getById(id: '8')).thenAnswer((_) {
      started.complete();
      return pending.future;
    });
    final result = command.execute.runAsync('8');
    await started.future;
    expect(command.execute.isRunning.value, isTrue);
    command.execute.run('9');
    pending.complete(Right(entity));
    expect((await result)?.right, same(entity));
    expect(command.execute.isRunning.value, isFalse);
    verify(() => repository.getById(id: '8')).called(1);
    verifyNoMoreInteractions(repository);
  });
  test('allows retry after failure and replaces the previous result', () async {
    final errors = ErrorsEntity.unknown();
    when(() => repository.getById(id: '8'))
        .thenAnswer((_) async => Left(errors));
    expect((await command.execute.runAsync('8'))?.left, same(errors));
    when(() => repository.getById(id: '8'))
        .thenAnswer((_) async => Right(entity));
    expect((await command.execute.runAsync('8'))?.right, same(entity));
    expect(command.execute.value?.right, same(entity));
    verify(() => repository.getById(id: '8')).called(2);
  });
  test('exposes unexpected repository exceptions as command errors', () async {
    final failure = StateError('failure');
    when(() => repository.getById(id: '8'))
        .thenAnswer((_) async => throw failure);
    void listener() {}
    command.execute.results.addListener(listener);
    try {
      await expectLater(command.execute.runAsync('8'), throwsA(same(failure)));
    } finally {
      command.execute.results.removeListener(listener);
    }
  });
  test('disposes the execution and loading observables', () async {
    final disposable = GetExpenseCommand(repository: repository);
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
