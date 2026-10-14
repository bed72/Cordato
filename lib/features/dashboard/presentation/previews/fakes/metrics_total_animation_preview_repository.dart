import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/domain/enums/expense_metrics_group_by_enum.dart';
import 'package:cordato/features/metrics/domain/repositories/interface_metrics_repository.dart';

final class MetricsTotalAnimationPreviewRepository
    implements IMetricsRepository {
  int totalCents = 389205;

  @override
  Future<GetExpensesRepositoryType> getExpenses({
    DateTime? endDate,
    DateTime? startDate,
    ExpenseMetricsGroupByEnum? groupBy,
  }) async {
    final total = totalCents;
    final start = startDate ?? DateTime(2026, 10);
    await Future<void>.delayed(const Duration(milliseconds: 400));

    return Right(
      ExpenseMetricsEntity(
        id: 'preview-${start.year}-${start.month}-$total',
        totalAmount: total,
        startDate: start,
        endDate: endDate ?? DateTime(start.year, start.month + 1, 0),
      ),
    );
  }
}
