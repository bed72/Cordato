import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/domain/enums/metrics_group_by_enum.dart';

abstract interface class IMetricsRepository {
  Future<ExpenseMetricsEntity> getExpenses({
    DateTime? endDate,
    DateTime? startDate,
    MetricsGroupByEnum? groupBy,
  });
}
