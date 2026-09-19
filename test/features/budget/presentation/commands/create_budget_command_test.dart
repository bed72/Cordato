import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/budget/domain/entities/budget_entity.dart';
import 'package:cordato/features/budget/domain/failures/budget_failure.dart';
import 'package:cordato/features/budget/presentation/commands/create_budget_command.dart';
import 'package:cordato/features/budget/domain/repositories/interface_budget_repository.dart';

class _BudgetRepositoryMock extends Mock implements IBudgetRepository {}

void main() {
  late BudgetEntity budget;
  late IBudgetRepository repository;
  late CreateBudgetCommand command;

  setUp(() {
    budget = BudgetEntity.create(
      amount: 100000,
      endDate: DateTime(2026, 9, 30),
      startDate: DateTime(2026, 9, 1),
    )!;
    repository = _BudgetRepositoryMock();
    command = CreateBudgetCommand(repository: repository);
  });

  tearDown(() => command.dispose());

  test('creates the budget through the repository', () async {
    when(() => repository.create(budget))
        .thenAnswer((_) async => const Right<BudgetFailure, void>(null));

    await command.create.runAsync(budget);

    verify(() => repository.create(budget)).called(1);
  });

  test('exposes repository failures as command errors', () async {
    when(() => repository.create(budget)).thenAnswer(
      (_) async => const Left<BudgetFailure, void>(BudgetOverlappingFailure()),
    );
    void onResult() {}

    command.create.results.addListener(onResult);
    await expectLater(
      command.create.runAsync(budget),
      throwsA(isA<BudgetOverlappingFailure>()),
    );
    command.create.results.removeListener(onResult);
  });
}
