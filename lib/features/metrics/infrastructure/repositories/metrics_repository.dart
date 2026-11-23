import 'dart:io';

import 'package:localstore/localstore.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/infrastructure/clients/widget_client.dart';

import 'package:cordato/features/expense/domain/enums/category_enum.dart';

import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/domain/enums/expense_metrics_group_by_enum.dart';

import 'package:cordato/features/metrics/application/exceptions/metrics_exception.dart';
import 'package:cordato/features/metrics/application/repositories/interface_metrics_repository.dart';
import 'package:cordato/features/metrics/infrastructure/responses/expense_category_metrics_response.dart';

final class MetricsRepository({
  required final Localstore _database,
  required final IWidgetClient _client,
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
    final revision = isCurrentMonth ? _client.monthlyRead() : null;

    try {
      final totals = <String, int>{};
      final documents = await _database.collection('expenses').get();

      for (final document in documents?.values ?? const <dynamic>[]) {
        final record = document as Map<String, dynamic>;
        final date = DateTime.parse(record['occurred_on'] as String);
        if (date.year != first.year || date.month != first.month) continue;

        final category = record['category'] as String;
        CategoryEnum.values.firstWhere((item) => item.value == category);
        final amount = record['amount'] as int;
        if (amount <= 0) throw const FormatException('Invalid expense amount');

        final previous = totals[category] ?? 0;
        final total = previous + amount;
        if (total < previous) throw const FormatException('Expense overflow');

        totals[category] = total;
      }

      final metrics = _monthlyMetrics(
        month: first,
        groupBy: groupBy,
        categories: totals.entries
            .map(
              (entry) => ExpenseCategoryMetricsResponse(
                category: entry.key,
                total: entry.value,
              ),
            )
            .toList(),
      );

      if (revision != null) {
        await _client.publishMonthly(
          month: first,
          revision: revision,
          cents: metrics.total,
        );
      }

      return metrics;
    } on FileSystemException {
      throw MetricsException(errors: .unknown());
    }
  }

  ExpenseMetricsEntity _monthlyMetrics({
    required DateTime month,
    required List<ExpenseCategoryMetricsResponse> categories,
    ExpenseMetricsGroupByEnum? groupBy,
  }) {
    int total = 0;
    final categoryKeys = <String>{};

    for (final category in categories) {
      if (!categoryKeys.add(category.category)) {
        throw const FormatException('Duplicate expense category group');
      }

      total += category.total;
      if (total < category.total) {
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
      total: total,
      startDate: month,
      endDate: DateTime(month.year, month.month + 1, 0),
      categories: groupBy == .category
          ? categories
                .map((category) => category.toEntity(monthlyTotal: total))
                .toList()
          : null,
    );
  }

  bool _isCompleteMonth({DateTime? startDate, DateTime? endDate}) {
    if (startDate == null && endDate == null) return true;
    if (startDate == null || endDate == null) return false;

    final last = DateTime(startDate.year, startDate.month + 1, 0);
    return startDate.day == 1 &&
        endDate.day == last.day &&
        endDate.year == last.year &&
        endDate.month == last.month;
  }
}
