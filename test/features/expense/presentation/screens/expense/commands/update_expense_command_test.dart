import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';
import 'package:cordato/features/expense/presentation/screens/expense/commands/update_expense_command.dart';

import '../../../../../../support/expense/mocks/expense_repository_mock.dart';

void main() {
  void onResult() {}
  late ExpenseRepositoryMock repository;
  late UpdateExpenseCommand command;
  late ExpenseEntity entity;

  setUp(() {
    repository = ExpenseRepositoryMock();
    command = UpdateExpenseCommand(repository: repository);
    command.execute.results.addListener(onResult);
    entity = ExpenseEntity(
      id: '8',
      cents: .create(cents: 1500).right,
      description: 'Ônibus e metrô',
      occurredOn: DateTime(2026, 10, 5),
      category: .other,
    );
  });

  tearDown(() {
    command.execute.results.removeListener(onResult);
    command.dispose();
  });

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

      final data = await command.execute.runAsync(parameters);

      expect(data, same(entity));
      expect(command.execute.value, same(entity));
      expect(command.execute.results.value.hasError, isFalse);
      expect(command.execute.results.value.data, same(entity));
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

        expect(await command.execute.runAsync(parameters), same(entity));

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
            parameter: 'amount',
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

      await expectLater(
        command.execute.runAsync((
          id: '8',
          cents: 0,
          description: '',
          occurredOn: null,
        )),
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

    final data = command.execute.runAsync((
      id: '8',
      cents: 1500,
      occurredOn: null,
      description: null,
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

    expect(await data, same(entity));
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

      await expectLater(
        command.execute.runAsync(parameters),
        throwsA(isA<CommandFailureException>()),
      );
      when(() => repository.update(id: '8', cents: 1500))
          .thenAnswer((_) async => Right(entity));

      expect(await command.execute.runAsync(parameters), same(entity));
      expect(command.execute.value, same(entity));
      expect(command.execute.errors.value, isNull);
      expect(command.execute.results.value.hasError, isFalse);
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

      expect(command.execute.value, same(entity));
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
    await expectLater(
      command.execute.runAsync((
        id: '8',
        cents: 1500,
        description: null,
        occurredOn: null,
      )),
      throwsA(same(failure)),
    );
    expect(command.execute.results.value.error, same(failure));
    expect(command.execute.errors.value?.error, same(failure));
  });

  test(
    'prioritizes an empty failure after a previous successful update',
    () async {
      const parameters = (
        id: '8',
        cents: 1500,
        description: null,
        occurredOn: null,
      );
      when(() => repository.update(id: '8', cents: 1500))
          .thenAnswer((_) async => Right(entity));
      await command.execute.runAsync(parameters);
      const errors = ErrorsEntity(errors: []);
      when(() => repository.update(id: '8', cents: 1500))
          .thenAnswer((_) async => const Left(errors));
      await expectLater(
        command.execute.runAsync(parameters),
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
      expect(command.execute.results.value.hasError, isTrue);
    },
  );

  test('does not publish an update after disposal while pending', () async {
    final disposable = UpdateExpenseCommand(repository: repository);
    final pending = Completer<UpdateRepositoryType>();
    final started = Completer<void>();
    when(() => repository.update(id: '8', cents: 1500)).thenAnswer((_) {
      started.complete();
      return pending.future;
    });
    final execution = disposable.execute.runAsync((
      id: '8',
      cents: 1500,
      description: null,
      occurredOn: null,
    ));
    await started.future;
    disposable.dispose();
    pending.complete(Right(entity));
    expect(await execution, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(disposable.execute.results.value.data, isNull);
    expect(disposable.execute.results.value.isRunning, isTrue);
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
