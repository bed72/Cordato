import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException, SupabaseClient;

import 'package:cordato/features/core/infrastructure/extensions/date_time_extension.dart';
import 'package:cordato/features/core/infrastructure/enums/postgres_error_code_enum.dart';
import 'package:cordato/features/core/infrastructure/enums/supabase_table_enum.dart';

import 'package:cordato/features/budget/domain/entities/budget_entity.dart';
import 'package:cordato/features/budget/infrastructure/enums/budget_create_outcome_enum.dart';

abstract interface class IBudgetClient {
  Future<BudgetCreateOutcomeEnum> create(BudgetEntity budget);
}

final class SupabaseBudgetClient implements IBudgetClient {
  final SupabaseClient client;

  const SupabaseBudgetClient({required this.client});

  @override
  Future<BudgetCreateOutcomeEnum> create(BudgetEntity budget) async {
    try {
      await client.from(SupabaseTableEnum.budgets.value).insert({
        'amount': budget.amount,
        'description': budget.description,
        'end_date': budget.endDate.toIsoDateString(),
        'start_date': budget.startDate.toIsoDateString(),
      });
      return .created;
    } on PostgrestException catch (error) {
      return error.code == PostgresErrorCodeEnum.exclusionViolation.value
          ? .overlapping
          : .failed;
    } catch (_) {
      return .failed;
    }
  }
}
