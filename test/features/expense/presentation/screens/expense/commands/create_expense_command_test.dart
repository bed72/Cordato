import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

import 'package:cordato/features/expense/presentation/screens/expense/commands/create_expense_command.dart';

import '../../../../../../support/expense/mocks/expense_repository_mock.dart';

void main() {
  late ExpenseEntity entity;
  late CreateExpenseCommand command;
  late ExpenseRepositoryMock repository;
  late ({int cents, String description, DateTime? occurredOn}) parameters;

  setUp(() {
    repository = ExpenseRepositoryMock();
    command = CreateExpenseCommand(repository: repository);
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

  tearDown(() => command.dispose());

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

      expect(data?.right, same(entity));
      expect(command.execute.value?.right, same(entity));
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

    final result = await command.execute.runAsync((
      cents: 300,
      occurredOn: null,
      description: ' Game ',
    ));

    expect(result?.right, same(entity));
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

    final data = await command.execute.runAsync(parameters);

    expect(data?.left, same(errors));
    expect(command.execute.value?.left, same(errors));
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

    expect((await data)?.right, same(entity));
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

    expect((await command.execute.runAsync(parameters))?.left, same(errors));
    when(
      () => repository.create(
        cents: parameters.cents,
        occurredOn: parameters.occurredOn,
        description: parameters.description,
      ),
    ).thenAnswer((_) async => Right(entity));

    expect((await command.execute.runAsync(parameters))?.right, same(entity));
    expect(command.execute.value?.right, same(entity));
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

    void onResult() {}
    command.execute.results.addListener(onResult);

    try {
      await expectLater(
        command.execute.runAsync(parameters),
        throwsA(same(failure)),
      );
    } finally {
      command.execute.results.removeListener(onResult);
    }
  });
}
