import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';
import 'package:cordato/features/expense/presentation/screens/expense/commands/get_expense_command.dart';

import '../../../../../../support/expense/mocks/expense_repository_mock.dart';

void main() {
  void onResult() {}
  late ExpenseEntity entity;
  late GetExpenseCommand command;
  late ExpenseRepositoryMock repository;

  setUp(() {
    repository = ExpenseRepositoryMock();
    command = GetExpenseCommand(repository: repository);
    command.execute.results.addListener(onResult);

    entity = ExpenseEntity(
      id: '8',
      category: .other,
      description: 'Ônibus e metrô',
      cents: .create(cents: 1500).right,
      occurredOn: DateTime(2026, 10, 5),
    );
  });

  tearDown(() {
    command.execute.results.removeListener(onResult);
    command.dispose();
  });

  test('waits for execution before fetching an expense', () {
    expect(command.execute.value, isNull);
    expect(command.execute.isRunning.value, isFalse);
    verifyZeroInteractions(repository);
  });

  test(
    'delegates the unchanged id and publishes the original expense',
    () async {
      final GetByIdRepositoryType response = Right(entity);
      when(() => repository.getById(id: 'a/b?c#d'))
          .thenAnswer((_) async => response);

      final result = await command.execute.runAsync('a/b?c#d');

      expect(result, same(entity));
      expect(command.execute.value, same(entity));
      expect(command.execute.results.value.hasError, isFalse);
      expect(command.execute.results.value.data, same(entity));
      expect(command.execute.results.value.paramData, 'a/b?c#d');
      verify(() => repository.getById(id: 'a/b?c#d')).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  test('preserves domain errors for the retry state', () async {
    const errors = ErrorsEntity(
      errors: [
        ErrorEntity(
          status: '404',
          parameter: 'id',
          pointer: '/data/id',
          title: 'Despesa não encontrada',
          detail: 'Confira a despesa solicitada.',
        ),
        ErrorEntity(title: 'Outro erro'),
      ],
    );

    const GetByIdRepositoryType response = Left(errors);
    when(() => repository.getById(id: '8')).thenAnswer((_) async => response);

    await expectLater(
      command.execute.runAsync('8'),
      throwsA(
        isA<CommandFailureException>().having(
          (failure) => failure.errors,
          'errors',
          same(errors),
        ),
      ),
    );

    final snapshot = command.execute.results.value;

    expect(snapshot.data, isNull);
    expect(snapshot.paramData, '8');
    expect(snapshot.hasError, isTrue);
    expect(command.execute.errors.value?.error, same(snapshot.error));
    expect((snapshot.error as CommandFailureException).errors, same(errors));
  });

  test('blocks repeated fetches while the request is pending', () async {
    final started = Completer<void>();
    final pending = Completer<GetByIdRepositoryType>();

    when(() => repository.getById(id: '8')).thenAnswer((_) {
      started.complete();
      return pending.future;
    });

    final data = command.execute.runAsync('8');

    await started.future;
    expect(command.execute.isRunning.value, isTrue);

    command.execute.run('9');
    final shared = command.execute.runAsync('9');

    expect(shared, same(data));
    pending.complete(Right(entity));
    expect(await data, same(entity));
    expect(await shared, same(entity));
    expect(command.execute.isRunning.value, isFalse);
    expect(command.execute.results.value.paramData, '8');
    verify(() => repository.getById(id: '8')).called(1);
    verifyNoMoreInteractions(repository);
  });

  test('allows retry after failure and replaces the previous result', () async {
    final errors = ErrorsEntity.unknown();
    when(() => repository.getById(id: '8'))
        .thenAnswer((_) async => Left(errors));

    await expectLater(
      command.execute.runAsync('8'),
      throwsA(isA<CommandFailureException>()),
    );

    when(() => repository.getById(id: '8'))
        .thenAnswer((_) async => Right(entity));

    final result = await command.execute.runAsync('8');

    expect(result, same(entity));
    expect(command.execute.value, same(entity));
    expect(command.execute.errors.value, isNull);
    expect(command.execute.results.value.hasError, isFalse);
    verify(() => repository.getById(id: '8')).called(2);
  });

  test('exposes unexpected repository exceptions as command errors', () async {
    final failure = StateError('failure');
    when(() => repository.getById(id: '8'))
        .thenAnswer((_) async => throw failure);
    await expectLater(command.execute.runAsync('8'), throwsA(same(failure)));

    expect(command.execute.results.value.error, same(failure));
    expect(command.execute.errors.value?.error, same(failure));
  });

  test('keeps old data out of the snapshot when a later query fails', () async {
    when(() => repository.getById(id: '8'))
        .thenAnswer((_) async => Right(entity));
    await command.execute.runAsync('8');
    const errors = ErrorsEntity(errors: []);
    when(() => repository.getById(id: '9'))
        .thenAnswer((_) async => const Left(errors));

    await expectLater(
      command.execute.runAsync('9'),
      throwsA(
        isA<CommandFailureException>().having(
          (failure) => failure.errors,
          'errors',
          same(errors),
        ),
      ),
    );

    expect(command.execute.value, same(entity));
    expect(command.execute.results.value.data, isNull);
    expect(command.execute.results.value.paramData, '9');
    expect(command.execute.results.value.hasError, isTrue);
  });

  test('publishes a new start and terminal for the requested id', () async {
    final pending = Completer<GetByIdRepositoryType>();
    when(() => repository.getById(id: '8')).thenAnswer((_) => pending.future);
    final initial = command.execute.results.value;

    final execution = command.execute.runAsync('8');
    final started = command.execute.results.value;

    expect(started.data, isNull);
    expect(started.paramData, '8');
    expect(started.isRunning, isTrue);
    expect(started, isNot(same(initial)));

    pending.complete(Right(entity));

    expect(await execution, same(entity));
    final terminal = command.execute.results.value;

    expect(terminal.paramData, '8');
    expect(terminal.data, same(entity));
    expect(terminal.isRunning, isFalse);
    expect(terminal, isNot(same(started)));
  });

  test('keeps results isolated between command instances', () async {
    final other = GetExpenseCommand(repository: repository);
    addTearDown(other.dispose);
    when(() => repository.getById(id: '8'))
        .thenAnswer((_) async => Right(entity));

    await command.execute.runAsync('8');

    expect(other.execute.value, isNull);
    expect(other.execute.isRunning.value, isFalse);
    expect(other.execute.results.value.data, isNull);
    verify(() => repository.getById(id: '8')).called(1);
  });

  test('does not publish a pending expense after disposal', () async {
    final disposable = GetExpenseCommand(repository: repository);
    when(() => repository.getById(id: '8'))
        .thenAnswer((_) async => Right(entity));
    await disposable.execute.runAsync('8');
    final started = Completer<void>();
    final pending = Completer<GetByIdRepositoryType>();
    when(() => repository.getById(id: '9')).thenAnswer((_) {
      started.complete();
      return pending.future;
    });
    final execution = disposable.execute.runAsync('9');
    await started.future;
    disposable.dispose();
    pending.complete(Right(entity));

    expect(await execution, same(entity));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(disposable.execute.results.value.data, isNull);
    expect(disposable.execute.results.value.paramData, '9');
    expect(disposable.execute.results.value.isRunning, isTrue);
    verify(() => repository.getById(id: '8')).called(1);
    verify(() => repository.getById(id: '9')).called(1);
    verifyNoMoreInteractions(repository);
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
