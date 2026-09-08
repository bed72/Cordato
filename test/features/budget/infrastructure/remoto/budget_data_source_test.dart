import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/budget/domain/entities/budget_entity.dart';
import 'package:cordato/features/budget/infrastructure/clients/supabase_budget_client.dart';
import 'package:cordato/features/budget/infrastructure/enums/budget_create_outcome_enum.dart';
import 'package:cordato/features/budget/infrastructure/remoto/budget_data_source.dart';

class _BudgetClientMock extends Mock implements IBudgetClient {}

void main() {
  test('delegates budget creation to the client', () async {
    final budget = BudgetEntity.create(
      amount: 100000,
      description: 'Viagem',
      endDate: DateTime(2026, 9, 30),
      startDate: DateTime(2026, 9, 1),
    )!;
    final client = _BudgetClientMock();
    final dataSource = BudgetDataSource(client: client);
    when(() => client.create(budget)).thenAnswer((_) async => .created);

    final result = await dataSource.create(budget);

    expect(result, BudgetCreateOutcomeEnum.created);
    verify(() => client.create(budget)).called(1);
  });
}
