import 'dart:async';

import 'package:cordato/features/metrics/application/exceptions/metrics_exception.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';

import 'package:cordato/features/metrics/domain/enums/expense_metrics_group_by_enum.dart';
import 'package:cordato/features/metrics/application/repositories/interface_metrics_repository.dart';

final class MetricsPreviewRepository({
  final ExpenseMetricsEntity? data,
  final ErrorsEntity? failure,
  final bool loading = false,
  final Duration delay = .zero,
}) implements IMetricsRepository {
  @override
  Future<ExpenseMetricsEntity> getExpenses({
    DateTime? endDate,
    DateTime? startDate,
    ExpenseMetricsGroupByEnum? groupBy,
  }) async {
    if (loading) return Completer<ExpenseMetricsEntity>().future;
    if (delay != Duration.zero) await Future<void>.delayed(delay);
    if (failure != null) throw MetricsException(errors: failure!);
    if (data != null) return data!;

    final start = startDate ?? DateTime(2026, 10, 1);

    if (start.month == 8) {
      throw MetricsException(errors: ErrorsEntity.unknown());
    }
    final empty = start.month == 9;

    return ExpenseMetricsEntity(
      id: 'preview-${start.year}-${start.month}',
      startDate: start,
      totalAmount: empty ? 0 : 389205,
      endDate: endDate ?? DateTime(start.year, start.month + 1, 0),
      categories: empty
          ? []
          : const [
              ExpenseCategoryMetricsEntity(
                percentage: 55.50,
                totalAmount: 216000,
                category: 'housing',
              ),
              ExpenseCategoryMetricsEntity(
                category: 'food',
                percentage: 28.44,
                totalAmount: 110700,
              ),
              ExpenseCategoryMetricsEntity(
                percentage: 7.77,
                totalAmount: 30240,
                category: 'health',
              ),
              ExpenseCategoryMetricsEntity(
                percentage: 6.24,
                totalAmount: 24300,
                category: 'transport',
              ),
              ExpenseCategoryMetricsEntity(
                percentage: 2.05,
                totalAmount: 7965,
                category: 'subscriptions',
              ),
            ],
    );
  }
}
