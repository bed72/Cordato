import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/failures/expense_failure.dart';
import 'package:cordato/features/expense/data/repositories/expense_repository.dart';
import 'package:cordato/features/expense/infrastructure/remoto/expense_data_source.dart';

class _ExpenseDataSourceMock extends Mock implements IExpenseDataSource {}

void main() {
  late ExpenseEntity expense;
  late ExpenseRepository repository;
  late IExpenseDataSource dataSource;

  setUp(() {
    expense = ExpenseEntity.create(
      amount: 1500,
      description: 'Almoço',
      date: DateTime(2026, 9, 8),
    )!;
    dataSource = _ExpenseDataSourceMock();
    repository = ExpenseRepository(dataSource: dataSource);
  });

  test('returns Right when the expense is created', () async {
    when(() => dataSource.create(expense)).thenAnswer((_) async => .created);

    final result = await repository.create(expense);

    expect(result, equals(const Right<ExpenseFailure, void>(null)));
    verify(() => dataSource.create(expense)).called(1);
  });

  test('returns ExpenseCreationFailure when persistence fails', () async {
    when(() => dataSource.create(expense)).thenAnswer((_) async => .failed);

    final result = await repository.create(expense);

    expect(result.left, isA<ExpenseCreationFailure>());
  });
}
