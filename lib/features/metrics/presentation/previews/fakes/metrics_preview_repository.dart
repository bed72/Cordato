import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';
import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/domain/enums/expense_metrics_group_by_enum.dart';
import 'package:cordato/features/metrics/domain/repositories/interface_metrics_repository.dart';

final class MetricsPreviewRepository({
  final GetExpensesRepositoryType? result,
  final Duration delay = Duration.zero,
}) implements IMetricsRepository {
  @override
  Future<GetExpensesRepositoryType> getExpenses({
    DateTime? startDate,
    DateTime? endDate,
    ExpenseMetricsGroupByEnum? groupBy,
  }) async {
    if (delay != Duration.zero) await Future<void>.delayed(delay);
    if (result != null) return result!;
    final start = startDate ?? DateTime(2026, 10, 1);
    if (start.month == 8) return Left(ErrorsEntity.unknown());
    final empty = start.month == 9;
    return Right(
      ExpenseMetricsEntity(
        id: 'preview-${start.year}-${start.month}',
        startDate: start,
        endDate: endDate ?? DateTime(start.year, start.month + 1, 0),
        totalAmount: empty ? 0 : 389205,
        categories: empty
            ? []
            : const [
                ExpenseCategoryMetricsEntity(
                  category: 'housing',
                  totalAmount: 216000,
                  percentage: 55.50,
                ),
                ExpenseCategoryMetricsEntity(
                  category: 'food',
                  totalAmount: 110700,
                  percentage: 28.44,
                ),
                ExpenseCategoryMetricsEntity(
                  category: 'health',
                  totalAmount: 30240,
                  percentage: 7.77,
                ),
                ExpenseCategoryMetricsEntity(
                  category: 'transport',
                  totalAmount: 24300,
                  percentage: 6.24,
                ),
                ExpenseCategoryMetricsEntity(
                  category: 'subscriptions',
                  totalAmount: 7965,
                  percentage: 2.05,
                ),
              ],
      ),
    );
  }
}
