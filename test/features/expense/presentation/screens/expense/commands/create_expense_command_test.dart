import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

import 'package:cordato/features/expense/presentation/screens/expense/commands/create_expense_command.dart';

import '../../../../../../support/expense/mocks/expense_repository_mock.dart';

void main() {
  void onResult() {}
  late ExpenseEntity entity;
  late CreateExpenseCommand command;
  late ExpenseRepositoryMock repository;
  late ({int cents, String description, DateTime? occurredOn}) parameters;

  setUp(() {
    repository = ExpenseRepositoryMock();
    command = CreateExpenseCommand(repository: repository);
    command.execute.results.addListener(onResult);
    parameters = (
      cents: 300,
      description: 'Game',
      occurredOn: DateTime(2026, 10, 5),
    );
    entity = ExpenseEntity(
      id: '9',
      category: .other,
      description: 'Game',
      cents: .create(cents: 300).right,
      occurredOn: DateTime(2026, 10, 5),
    );
  });

  tearDown(() {
    command.execute.results.removeListener(onResult);
    command.dispose();
  });

  test('waits for execution before requesting expense creation', () {
    expect(command.execute.value, isNull);
    expect(command.execute.isRunning.value, isFalse);
    verifyZeroInteractions(repository);
  });

  test(
    'delegates creation parameters and publishes the registered expense',
    () async {
      when(
        () => repository.create(
          cents: parameters.cents,
          occurredOn: parameters.occurredOn,
          description: parameters.description,
        ),
      ).thenAnswer((_) async => Right(entity));

      final data = await command.execute.runAsync(parameters);

      expect(data, same(entity));
      expect(command.execute.value, same(entity));
      expect(command.execute.results.value.data, same(entity));
      expect(command.execute.results.value.hasError, isFalse);
      verify(
        () => repository.create(
          cents: parameters.cents,
          description: parameters.description,
          occurredOn: parameters.occurredOn,
        ),
      ).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  test('delegates a null occurrence date without applying a default', () async {
    when(
      () => repository.create(
        cents: 300,
        occurredOn: null,
        description: ' Game ',
      ),
    ).thenAnswer((_) async => Right(entity));

    final data = await command.execute.runAsync((
      cents: 300,
      occurredOn: null,
      description: ' Game ',
    ));

    expect(data, same(entity));
    verify(
      () => repository.create(
        cents: 300,
        occurredOn: null,
        description: ' Game ',
      ),
    ).called(1);

    verifyNoMoreInteractions(repository);
  });

  test('preserves all domain errors and field pointers for feedback', () async {
    const errors = ErrorsEntity(
      errors: [
        ErrorEntity(
          status: '422',
          title: 'Descrição inválida',
          detail: 'Informe uma descrição.',
          pointer: '/data/attributes/description',
          parameter: 'description',
        ),
        ErrorEntity(
          title: 'Valor inválido',
          detail: 'O valor da despesa deve ser maior que zero.',
        ),
      ],
    );
    when(
      () => repository.create(
        cents: parameters.cents,
        occurredOn: parameters.occurredOn,
        description: parameters.description,
      ),
    ).thenAnswer((_) async => const Left(errors));

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
    final snapshot = command.execute.results.value;
    expect(snapshot.hasError, isTrue);
    expect(snapshot.data, isNull);
    expect((snapshot.error as CommandFailureException).errors, same(errors));
    expect(command.execute.errors.value?.error, same(snapshot.error));
    verify(
      () => repository.create(
        cents: parameters.cents,
        description: parameters.description,
        occurredOn: parameters.occurredOn,
      ),
    ).called(1);
    verifyNoMoreInteractions(repository);
  });

  test('prevents additional creation while a request is pending', () async {
    final started = Completer<void>();
    final pending = Completer<CreateRepositoryType>();
    when(
      () => repository.create(
        cents: parameters.cents,
        occurredOn: parameters.occurredOn,
        description: parameters.description,
      ),
    ).thenAnswer((_) {
      started.complete();
      return pending.future;
    });

    final data = command.execute.runAsync(parameters);
    await started.future;
    expect(command.execute.isRunning.value, isTrue);
    command.execute.run(parameters);
    verify(
      () => repository.create(
        cents: parameters.cents,
        occurredOn: parameters.occurredOn,
        description: parameters.description,
      ),
    ).called(1);
    pending.complete(Right(entity));

    expect(await data, same(entity));
    expect(command.execute.isRunning.value, isFalse);
    verifyNoMoreInteractions(repository);
  });

  test('allows another attempt after an unsuccessful creation', () async {
    final errors = ErrorsEntity.unknown();
    when(
      () => repository.create(
        cents: parameters.cents,
        occurredOn: parameters.occurredOn,
        description: parameters.description,
      ),
    ).thenAnswer((_) async => Left(errors));

    await expectLater(
      command.execute.runAsync(parameters),
      throwsA(isA<CommandFailureException>()),
    );
    when(
      () => repository.create(
        cents: parameters.cents,
        occurredOn: parameters.occurredOn,
        description: parameters.description,
      ),
    ).thenAnswer((_) async => Right(entity));

    expect(await command.execute.runAsync(parameters), same(entity));
    expect(command.execute.value, same(entity));
    expect(command.execute.results.value.hasError, isFalse);
    expect(command.execute.errors.value, isNull);
    verify(
      () => repository.create(
        cents: parameters.cents,
        description: parameters.description,
        occurredOn: parameters.occurredOn,
      ),
    ).called(2);
    verifyNoMoreInteractions(repository);
  });

  test('exposes unexpected repository exceptions as command errors', () async {
    final failure = StateError('repository unavailable');
    when(
      () => repository.create(
        cents: parameters.cents,
        occurredOn: parameters.occurredOn,
        description: parameters.description,
      ),
    ).thenAnswer((_) async => throw failure);

    await expectLater(
      command.execute.runAsync(parameters),
      throwsA(same(failure)),
    );
    expect(command.execute.results.value.error, same(failure));
    expect(command.execute.errors.value?.error, same(failure));
  });

  test(
    'keeps previous success out of a later empty failure snapshot',
    () async {
      when(
        () => repository.create(
          cents: parameters.cents,
          description: parameters.description,
          occurredOn: parameters.occurredOn,
        ),
      ).thenAnswer((_) async => Right(entity));
      await command.execute.runAsync(parameters);
      const errors = ErrorsEntity(errors: []);
      when(
        () => repository.create(
          cents: parameters.cents,
          description: parameters.description,
          occurredOn: parameters.occurredOn,
        ),
      ).thenAnswer((_) async => const Left(errors));
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

  test('keeps creation state isolated between instances', () async {
    final other = CreateExpenseCommand(repository: repository);
    addTearDown(other.dispose);
    when(
      () => repository.create(
        cents: parameters.cents,
        description: parameters.description,
        occurredOn: parameters.occurredOn,
      ),
    ).thenAnswer((_) async => Right(entity));
    await command.execute.runAsync(parameters);
    expect(other.execute.value, isNull);
    expect(other.execute.results.value.data, isNull);
    expect(other.execute.isRunning.value, isFalse);
  });

  test('does not publish creation after disposal while pending', () async {
    final disposable = CreateExpenseCommand(repository: repository);
    final pending = Completer<CreateRepositoryType>();
    final started = Completer<void>();
    when(
      () => repository.create(
        cents: parameters.cents,
        description: parameters.description,
        occurredOn: parameters.occurredOn,
      ),
    ).thenAnswer((_) {
      started.complete();
      return pending.future;
    });
    final execution = disposable.execute.runAsync(parameters);
    await started.future;
    disposable.dispose();
    pending.complete(Right(entity));
    expect(await execution, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(disposable.execute.results.value.data, isNull);
    expect(disposable.execute.results.value.isRunning, isTrue);
  });
}
