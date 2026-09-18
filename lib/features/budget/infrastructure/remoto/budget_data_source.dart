import 'package:cordato/features/budget/domain/entities/budget_entity.dart';
import 'package:cordato/features/budget/infrastructure/clients/supabase_budget_client.dart';
import 'package:cordato/features/budget/infrastructure/enums/budget_create_outcome_enum.dart';

abstract interface class IBudgetDataSource {
  Future<BudgetCreateOutcomeEnum> create(BudgetEntity budget);
}

final class const BudgetDataSource({required final IBudgetClient client})
    implements IBudgetDataSource {
  @override
  Future<BudgetCreateOutcomeEnum> create(BudgetEntity budget) =>
      client.create(budget);
}
