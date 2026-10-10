import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/domain/enums/expense_metrics_group_by_enum.dart';

typedef GetExpensesRepositoryType = Either<ErrorsEntity, ExpenseMetricsEntity>;

abstract interface class IMetricsRepository {
  Future<GetExpensesRepositoryType> getExpenses({
    DateTime? endDate,
    DateTime? startDate,
    ExpenseMetricsGroupByEnum? groupBy,
  });
}
