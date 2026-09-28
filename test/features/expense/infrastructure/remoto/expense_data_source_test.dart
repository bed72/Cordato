import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/infrastructure/remoto/expense_data_source.dart';
import 'package:cordato/features/expense/infrastructure/clients/expense_client.dart';
import 'package:cordato/features/expense/infrastructure/enums/expense_create_outcome_enum.dart';

class _ExpenseClientMock extends Mock implements IExpenseClient {}

void main() {
  test('delegates expense creation to the client', () async {
    final expense = ExpenseEntity.create(
      amount: 1500,
      description: 'Almoço',
      date: DateTime(2026, 9, 8),
    )!;
    final client = _ExpenseClientMock();
    final dataSource = ExpenseDataSource(client: client);
    when(() => client.create(expense)).thenAnswer((_) async => .created);

    final data = await dataSource.create(expense);

    expect(data, ExpenseCreateOutcomeEnum.created);
    verify(() => client.create(expense)).called(1);
  });
}
