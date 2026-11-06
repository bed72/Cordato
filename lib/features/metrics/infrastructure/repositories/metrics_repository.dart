import 'package:pocketbase/pocketbase.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/application/clients/interface_home_widget_client.dart';

import 'package:cordato/features/core/infrastructure/serializers/date_serializer.dart';
import 'package:cordato/features/core/infrastructure/clients/pocketbase/pocketbase_mapper.dart';

import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/domain/enums/expense_metrics_group_by_enum.dart';

import 'package:cordato/features/metrics/infrastructure/responses/expense_metrics_response.dart';

import 'package:cordato/features/metrics/application/exceptions/metrics_exception.dart';
import 'package:cordato/features/metrics/application/repositories/interface_metrics_repository.dart';

final class MetricsRepository({
  required final PocketBase _pocketBase,
  required final IHomeWidgetClient _homeWidgetClient,
}) implements IMetricsRepository {
  @override
  Future<ExpenseMetricsEntity> getExpenses({
    DateTime? endDate,
    DateTime? startDate,
    ExpenseMetricsGroupByEnum? groupBy,
  }) async {
    final now = DateTime.now();
    final start = startDate ?? DateTime(now.year, now.month);

    final first = DateTime(start.year, start.month);
    final last = DateTime(start.year, start.month + 1, 0);
    final isCurrentMonth = first.year == now.year && first.month == now.month;

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

    final widgetRevision = isCurrentMonth
        ? _homeWidgetClient.beginMonthlyRead()
        : null;

    try {
      final response = await _pocketBase.send<Map<String, dynamic>>(
        '/api/collections/metrics/records',
        query: {
          'page': 1,
          'perPage': 2,
          'skipTotal': true,
          'filter': _pocketBase.filter('start_date = {:month}', {
            'month': dateSerializer(first),
          }),
        },
      );

      final items = response['items'] as List;
      if (items.isEmpty) {
        if (widgetRevision != null) {
          await _homeWidgetClient.publishMonthlyTotal(
            cents: 0,
            month: first,
            revision: widgetRevision,
          );
        }

        return ExpenseMetricsEntity(
          endDate: last,
          totalAmount: 0,
          startDate: first,
          id: 'empty-${dateSerializer(first)}',
          categories: groupBy == .category ? const [] : null,
        );
      }
      if (items.length != 1) throw const FormatException('Métricas duplicadas');

      final metrics = ExpenseMetricsResponse.fromJson(
        items.single as Map<String, dynamic>,
      ).toEntity();

      if (metrics.startDate != first || metrics.endDate != last) {
        throw const FormatException('Período das métricas inválido');
      }

      if (widgetRevision != null) {
        await _homeWidgetClient.publishMonthlyTotal(
          month: first,
          revision: widgetRevision,
          cents: metrics.totalAmount,
        );
      }

      return ExpenseMetricsEntity(
        id: metrics.id,
        endDate: metrics.endDate,
        startDate: metrics.startDate,
        totalAmount: metrics.totalAmount,
        categories: groupBy == .category ? metrics.categories : null,
      );
    } on ClientException catch (exception) {
      throw MetricsException(errors: PocketBaseMapper.fromException(exception));
    }
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
