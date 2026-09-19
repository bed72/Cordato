import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/either.dart';

import 'package:cordato/features/budget/domain/entities/budget_entity.dart';
import 'package:cordato/features/budget/domain/failures/budget_failure.dart';
import 'package:cordato/features/budget/data/repositories/budget_repository.dart';
import 'package:cordato/features/budget/infrastructure/remoto/budget_data_source.dart';

class _BudgetDataSourceMock extends Mock implements IBudgetDataSource {}

void main() {
  late BudgetEntity budget;
  late IBudgetDataSource dataSource;
  late BudgetRepository repository;

  setUp(() {
    budget = BudgetEntity.create(
      amount: 100000,
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 30),
    )!;
    dataSource = _BudgetDataSourceMock();
    repository = BudgetRepository(dataSource: dataSource);
  });

  test('returns Right when the budget is created', () async {
    when(() => dataSource.create(budget)).thenAnswer((_) async => .created);

    final result = await repository.create(budget);

    expect(result, equals(const Right<BudgetFailure, void>(null)));
    verify(() => dataSource.create(budget)).called(1);
  });

  test('returns BudgetOverlappingFailure when periods overlap', () async {
    when(() => dataSource.create(budget)).thenAnswer((_) async => .overlapping);

    final result = await repository.create(budget);

    expect(result.left, isA<BudgetOverlappingFailure>());
  });

  test('returns BudgetCreationFailure when persistence fails', () async {
    when(() => dataSource.create(budget)).thenAnswer((_) async => .failed);

    final result = await repository.create(budget);

    expect(result.left, isA<BudgetCreationFailure>());
  });
}
