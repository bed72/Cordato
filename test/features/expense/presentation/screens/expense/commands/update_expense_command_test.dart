import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';
import 'package:cordato/features/expense/presentation/screens/expense/commands/update_expense_command.dart';

import '../../../../../../support/expense/mocks/expense_repository_mock.dart';

void main() {
  late ExpenseRepositoryMock repository;
  late UpdateExpenseCommand command;
  late ExpenseEntity entity;

  setUp(() {
    repository = ExpenseRepositoryMock();
    command = UpdateExpenseCommand(repository: repository);
    entity = ExpenseEntity(
      id: '8',
      cents: .create(cents: 1500).right,
      description: 'Ônibus e metrô',
      occurredOn: DateTime(2026, 10, 5),
      category: .other,
    );
  });

  tearDown(() => command.dispose());

  test('waits for execution before updating an expense', () {
    expect(command.execute.value, isNull);
    expect(command.execute.isRunning.value, isFalse);
    verifyZeroInteractions(repository);
  });

  test(
    'delegates unchanged parameters and preserves the repository result',
    () async {
      final parameters = (
        id: 'a/b?c#d',
        cents: 1500,
        description: ' Ônibus e metrô ',
        occurredOn: DateTime.utc(2026, 10, 6, 23, 30),
      );
      final UpdateRepositoryType response = Right(entity);
      when(
        () => repository.update(
          id: parameters.id,
          cents: parameters.cents,
          description: parameters.description,
          occurredOn: parameters.occurredOn,
        ),
      ).thenAnswer((_) async => response);

      final result = await command.execute.runAsync(parameters);

      expect(result, same(response));
      expect(result?.right, same(entity));
      expect(command.execute.value, same(response));
      verify(
        () => repository.update(
          id: parameters.id,
          cents: parameters.cents,
          description: parameters.description,
          occurredOn: parameters.occurredOn,
        ),
      ).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  test(
    'delegates partial updates and null attributes without defaults',
    () async {
      for (final parameters in [
        (id: '8', cents: 1500, description: null, occurredOn: null),
        (id: '8', cents: null, description: 'Ônibus e metrô', occurredOn: null),
        (id: '8', cents: null, description: null, occurredOn: null),
        (id: '8', cents: 0, description: '', occurredOn: null),
        (
          id: '8',
          cents: null,
          description: null,
          occurredOn: DateTime(2026, 10, 6),
        ),
      ]) {
        when(
          () => repository.update(
            id: parameters.id,
            cents: parameters.cents,
            description: parameters.description,
            occurredOn: parameters.occurredOn,
          ),
        ).thenAnswer((_) async => Right(entity));

        expect(
          (await command.execute.runAsync(parameters))?.right,
          same(entity),
        );

        verify(
          () => repository.update(
            id: parameters.id,
            cents: parameters.cents,
            description: parameters.description,
            occurredOn: parameters.occurredOn,
          ),
        ).called(1);
      }
      verifyNoMoreInteractions(repository);
    },
  );

  test(
    'preserves domain errors and field pointers for presentation feedback',
    () async {
      const errors = ErrorsEntity(
        errors: [
          ErrorEntity(
            title: 'Valor inválido',
            detail: 'Informe um valor positivo.',
            status: '422',
            pointer: '/data/attributes/amount',
          ),
          ErrorEntity(
            title: 'Descrição inválida',
            detail: 'Informe uma descrição.',
            status: '422',
            pointer: '/data/attributes/description',
          ),
          ErrorEntity(
            title: 'Data inválida',
            status: '422',
            pointer: '/data/attributes/occurred_on',
          ),
        ],
      );
      const UpdateRepositoryType response = Left(errors);
      when(() => repository.update(id: '8', cents: 0, description: ''))
          .thenAnswer((_) async => response);

      final result = await command.execute.runAsync((
        id: '8',
        cents: 0,
        description: '',
        occurredOn: null,
      ));

      expect(result, same(response));
      expect(result?.left, same(errors));
      expect(command.execute.value, same(response));
      verify(() => repository.update(id: '8', cents: 0, description: ''))
          .called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  test('prevents additional updates while a request is pending', () async {
    final started = Completer<void>();
    final pending = Completer<UpdateRepositoryType>();
    when(() => repository.update(id: '8', cents: 1500)).thenAnswer((_) {
      started.complete();
      return pending.future;
    });

    final result = command.execute.runAsync((
      id: '8',
      cents: 1500,
      description: null,
      occurredOn: null,
    ));
    await started.future;
    expect(command.execute.isRunning.value, isTrue);
    command.execute.run((
      id: '9',
      cents: 2000,
      description: null,
      occurredOn: null,
    ));
    verify(() => repository.update(id: '8', cents: 1500)).called(1);
    pending.complete(Right(entity));

    expect((await result)?.right, same(entity));
    expect(command.execute.isRunning.value, isFalse);
    verifyNoMoreInteractions(repository);
  });

  test(
    'allows retry after a repository error and replaces the previous result',
    () async {
      const parameters = (
        id: '8',
        cents: 1500,
        description: null,
        occurredOn: null,
      );
      final errors = ErrorsEntity.unknown();
      when(() => repository.update(id: '8', cents: 1500))
          .thenAnswer((_) async => Left(errors));

      expect((await command.execute.runAsync(parameters))?.left, same(errors));
      when(() => repository.update(id: '8', cents: 1500))
          .thenAnswer((_) async => Right(entity));

      expect((await command.execute.runAsync(parameters))?.right, same(entity));
      expect(command.execute.value?.right, same(entity));
      verify(() => repository.update(id: '8', cents: 1500)).called(2);
      verifyNoMoreInteractions(repository);
    },
  );

  test('keeps update state isolated between command instances', () async {
    final otherCommand = UpdateExpenseCommand(repository: repository);
    when(() => repository.update(id: '8', cents: 1500))
        .thenAnswer((_) async => Right(entity));
    try {
      await command.execute.runAsync((
        id: '8',
        cents: 1500,
        description: null,
        occurredOn: null,
      ));

      expect(command.execute.value?.right, same(entity));
      expect(otherCommand.execute.value, isNull);
      expect(otherCommand.execute.isRunning.value, isFalse);
    } finally {
      otherCommand.dispose();
    }
  });

  test('exposes unexpected repository exceptions as command errors', () async {
    final failure = StateError('repository unavailable');
    when(() => repository.update(id: '8', cents: 1500))
        .thenAnswer((_) async => throw failure);
    void onResult() {}
    command.execute.results.addListener(onResult);
    try {
      await expectLater(
        command.execute.runAsync((
          id: '8',
          cents: 1500,
          description: null,
          occurredOn: null,
        )),
        throwsA(same(failure)),
      );
    } finally {
      command.execute.results.removeListener(onResult);
    }
  });

  test('disposes the observable execution and its loading state', () async {
    final disposable = UpdateExpenseCommand(repository: repository);
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
