import 'dart:convert';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_path_enum.dart';
import 'package:cordato/features/core/infrastructure/serializers/civil_date_serializer.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';

import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/domain/enums/expense_metrics_group_by_enum.dart';

import 'package:cordato/features/metrics/infrastructure/responses/expense_metrics_response.dart';

import 'package:cordato/features/metrics/application/exceptions/metrics_exception.dart';
import 'package:cordato/features/metrics/application/repositories/interface_metrics_repository.dart';

final class MetricsRepository({required final IHttpClient _httpClient})
    implements IMetricsRepository {
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

    try {
      final response = await _httpClient.get(
        parameter: Requests(
          path: HttpPathEnum.expenseMetrics.path,
          query: {
            'page': 1,
            'perPage': 2,
            'skipTotal': true,
            'filter': 'start_date = ${jsonEncode(formatDateSerializer(first))}',
          },
        ),
      );

      final items = response.body['items'] as List;
      if (items.isEmpty) {
        return ExpenseMetricsEntity(
          endDate: last,
          totalAmount: 0,
          startDate: first,
          id: 'empty-${formatDateSerializer(first)}',
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

      return ExpenseMetricsEntity(
        id: metrics.id,
        endDate: metrics.endDate,
        startDate: metrics.startDate,
        totalAmount: metrics.totalAmount,
        categories: groupBy == .category ? metrics.categories : null,
      );
    } on HttpResponseException catch (exception) {
      throw MetricsException(errors: exception.errors.toEntity());
    } on HttpClientException {
      throw MetricsException(errors: .unknown());
    }
  }

  bool _isCompleteMonth({DateTime? startDate, DateTime? endDate}) {
    if (startDate == null && endDate == null) return true;
    if (startDate == null || endDate == null) return false;

    final last = DateTime(startDate.year, startDate.month + 1, 0);
    return startDate.day == 1 &&
        endDate.year == last.year &&
        endDate.month == last.month &&
        endDate.day == last.day;
  }
}
