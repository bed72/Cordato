import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/infrastructure/clients/widget_client.dart';
import 'package:cordato/features/core/infrastructure/clients/database/database_date_codec.dart';
import 'package:cordato/features/core/infrastructure/clients/database/database_operation.dart';

import 'package:cordato/features/expense/domain/enums/category_enum.dart';

import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/domain/enums/metrics_group_by_enum.dart';

import 'package:cordato/features/metrics/application/exceptions/metrics_exception.dart';
import 'package:cordato/features/metrics/application/repositories/interface_metrics_repository.dart';

import 'package:cordato/features/metrics/infrastructure/daos/metrics_dao.dart';
import 'package:cordato/features/metrics/infrastructure/responses/expense_category_metrics_response.dart';

final class MetricsRepository({
  required final MetricsDao _dao,
  required final IWidgetClient _client,
}) implements IMetricsRepository {
  @override
  Future<ExpenseMetricsEntity> getExpenses({
    DateTime? endDate,
    DateTime? startDate,
    MetricsGroupByEnum? groupBy,
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
    final from = encodeDatabaseDate(first, parameter: 'startDate');
    final to = encodeDatabaseDate(
      DateTime(first.year, first.month + 1, 0),
      parameter: 'endDate',
    );
    final isCurrentMonth = first.year == now.year && first.month == now.month;
    final revision = isCurrentMonth ? _client.monthlyRead() : null;

    final metrics = await runDatabaseOperation(
      operation: () async {
        final records = await _dao.get(from: from, to: to);

        for (final record in records) {
          CategoryEnum.fromValue(record.category);
          if (record.minimumAmount <= 0 || record.total <= 0) {
            throw const FormatException('Invalid expense amount');
          }
        }

        return _monthlyMetrics(
          month: first,
          groupBy: groupBy,
          categories: records
              .map(ExpenseCategoryMetricsResponse.fromRecord)
              .toList(),
        );
      },
      onFailure: () => MetricsException(errors: .unknown()),
    );

    if (revision != null) {
      await _client.publishMonthly(
        month: first,
        revision: revision,
        cents: metrics.total,
      );
    }

    return metrics;
  }

  ExpenseMetricsEntity _monthlyMetrics({
    required DateTime month,
    required List<ExpenseCategoryMetricsResponse> categories,
    MetricsGroupByEnum? groupBy,
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
