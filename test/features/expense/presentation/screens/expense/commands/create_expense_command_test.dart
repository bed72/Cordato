import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/failures/expense_failure.dart';
import 'package:cordato/features/expense/presentation/screens/expense/commands/create_expense_command.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

class _ExpenseRepositoryMock extends Mock implements IExpenseRepository {}

void main() {
  late ExpenseEntity expense;
  late CreateExpenseCommand command;
  late IExpenseRepository repository;

  setUp(() {
    expense = ExpenseEntity.create(
      amount: 1500,
      description: 'Almoço',
      date: DateTime(2026, 9, 8),
    )!;
    repository = _ExpenseRepositoryMock();
    command = CreateExpenseCommand(repository: repository);
  });

  tearDown(() => command.dispose());

  test('creates the expense through the repository', () async {
    when(() => repository.create(expense))
        .thenAnswer((_) async => const Right<ExpenseFailure, void>(null));

    await command.create.runAsync(expense);

    verify(() => repository.create(expense)).called(1);
  });

  test('exposes repository failures as command errors', () async {
    when(() => repository.create(expense)).thenAnswer(
      (_) async => const Left<ExpenseFailure, void>(ExpenseCreationFailure()),
    );
    void onResult() {}

    command.create.results.addListener(onResult);
    await expectLater(
      command.create.runAsync(expense),
      throwsA(isA<ExpenseCreationFailure>()),
    );
    command.create.results.removeListener(onResult);
  });
}
