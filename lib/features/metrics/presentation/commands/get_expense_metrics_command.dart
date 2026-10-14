import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
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
    ExpenseMetricsEntity?
  >
  execute =
      Command.createAsync<
        ({
          DateTime? endDate,
          DateTime? startDate,
          ExpenseMetricsGroupByEnum? groupBy,
        }),
        ExpenseMetricsEntity?
      >(
        initialValue: null,
        (filters) async => switch (await repository.getExpenses(
          endDate: filters.endDate,
          groupBy: filters.groupBy,
          startDate: filters.startDate,
        )) {
          Right(:final value) => value,
          Left(:final value) => throw CommandFailureException(errors: value),
        },
      );

  @override
  void dispose() => execute.dispose();
}
