import 'dart:io';

import 'package:tostore/tostore.dart';

import 'package:cordato/features/core/application/clients/interface_home_widget_client.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/metrics/application/exceptions/metrics_exception.dart';
import 'package:cordato/features/metrics/application/repositories/interface_metrics_repository.dart';
import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/domain/enums/expense_metrics_group_by_enum.dart';
import 'package:cordato/features/metrics/infrastructure/mappers/metrics_mapper.dart';
import 'package:cordato/features/metrics/infrastructure/responses/expense_category_metrics_response.dart';

final class MetricsRepository({
  required final ToStore _database,
  required final IHomeWidgetClient _client,
}) implements IMetricsRepository {
  @override
  Future<ExpenseMetricsEntity> getExpenses({
    DateTime? endDate,
    DateTime? startDate,
    ExpenseMetricsGroupByEnum? groupBy,
  }) async {
    if (!_isCompleteMonth(startDate: startDate, endDate: endDate)) {
      throw MetricsException(
        errors: const ErrorsEntity(
          errors: [
            ErrorEntity(
              parameter: 'period',
              title: 'Período inválido',
              detail: 'Informe o primeiro e o último dia do mesmo mês.',
            ),
          ],
        ),
      );
    }

    final now = DateTime.now();
    final start = startDate ?? now;
    final first = DateTime(start.year, start.month);
    final isCurrentMonth = first.year == now.year && first.month == now.month;
    final widgetRevision = isCurrentMonth ? _client.beginMonthlyRead() : null;

    try {
      final groups = await _database
          .query('expenses')
          .where(
            'occurred_on',
            '>=',
            DateTime.utc(first.year, first.month).toIso8601String(),
          )
          .where(
            'occurred_on',
            '<',
            DateTime.utc(first.year, first.month + 1).toIso8601String(),
          )
          .groupBy(['category'])
          .selectAgg(['category', Agg.sum('amount', alias: 'total_amount')])
          .future;
      MetricsMapper.checkQuery(groups);

      final metrics = _monthlyMetrics(
        categories: groups.data
            .map(ExpenseCategoryMetricsResponse.fromJson)
            .toList(),
        month: first,
        groupBy: groupBy,
      );

      if (widgetRevision != null) {
        await _client.publishMonthlyTotal(
          month: first,
          revision: widgetRevision,
          cents: metrics.totalAmount,
        );
      }

      return metrics;
    } on DbException catch (exception) {
      throw MetricsMapper.failure(exception);
    } on FileSystemException {
      throw MetricsException(errors: .unknown());
    }
  }

  ExpenseMetricsEntity _monthlyMetrics({
    required List<ExpenseCategoryMetricsResponse> categories,
    required DateTime month,
    ExpenseMetricsGroupByEnum? groupBy,
  }) {
    int totalAmount = 0;
    final categoryKeys = <String>{};

    for (final category in categories) {
      if (!categoryKeys.add(category.category)) {
        throw const FormatException('Duplicate expense category group');
      }

      totalAmount += category.totalAmount;
      if (totalAmount < category.totalAmount) {
        throw const FormatException('Expense total overflow');
      }
    }

    categories.sort(
      (first, second) => first.category.compareTo(second.category),
    );
    final monthKey =
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';

    return ExpenseMetricsEntity(
      id: 'monthly-$monthKey',
      startDate: month,
      endDate: DateTime(month.year, month.month + 1, 0),
      totalAmount: totalAmount,
      categories: groupBy == .category
          ? categories
                .map((category) => category.toEntity(monthlyTotal: totalAmount))
                .toList()
          : null,
    );
  }

  bool _isCompleteMonth({DateTime? startDate, DateTime? endDate}) {
    if (startDate == null && endDate == null) {
      return true;
    }
    if (startDate == null || endDate == null) {
      return false;
    }

    final last = DateTime(startDate.year, startDate.month + 1, 0);
    return startDate.day == 1 &&
        endDate.day == last.day &&
        endDate.year == last.year &&
        endDate.month == last.month;
  }
}
