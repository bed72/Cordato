import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/metrics/domain/enums/expense_metrics_group_by_enum.dart';
import 'package:cordato/features/metrics/domain/repositories/interface_metrics_repository.dart';

final class GetExpenseMetricsCommand({required IMetricsRepository repository})
    implements ICommand {
  final Command<
    ({
      DateTime? endDate,
      DateTime? startDate,
      ExpenseMetricsGroupByEnum? groupBy,
    }),
    GetExpensesRepositoryType?
  >
  execute =
      Command.createAsync<
        ({
          DateTime? endDate,
          DateTime? startDate,
          ExpenseMetricsGroupByEnum? groupBy,
        }),
        GetExpensesRepositoryType?
      >(
        initialValue: null,
        (filters) => repository.getExpenses(
          endDate: filters.endDate,
          groupBy: filters.groupBy,
          startDate: filters.startDate,
        ),
      );

  @override
  void dispose() => execute.dispose();
}
