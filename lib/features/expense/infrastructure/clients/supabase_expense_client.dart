import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cordato/features/core/infrastructure/extensions/date_time_extension.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/infrastructure/enums/expense_create_outcome_enum.dart';

abstract interface class IExpenseClient {
  Future<ExpenseCreateOutcomeEnum> create(ExpenseEntity expense);
}

final class SupabaseExpenseClient implements IExpenseClient {
  final SupabaseClient client;

  const SupabaseExpenseClient({required this.client});

  @override
  Future<ExpenseCreateOutcomeEnum> create(ExpenseEntity expense) async {
    try {
      await client.rpc(
        'create_expense',
        params: {
          'p_amount': expense.amount,
          'p_description': expense.description,
          'p_date': expense.date.toIsoDateString(),
        },
      );
      return .created;
    } catch (_) {
      return .failed;
    }
  }
}
