import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_path_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';
import 'package:cordato/features/core/infrastructure/serializers/civil_date_serializer.dart';
import 'package:cordato/features/metrics/application/exceptions/metrics_exception.dart';
import 'package:cordato/features/metrics/application/repositories/interface_metrics_repository.dart';
import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/domain/enums/expense_metrics_group_by_enum.dart';
import 'package:cordato/features/metrics/infrastructure/responses/expense_metrics_response.dart';

final class MetricsRepository({required final IHttpClient _httpClient})
    implements IMetricsRepository {
  @override
  Future<ExpenseMetricsEntity> getExpenses({
    DateTime? endDate,
    DateTime? startDate,
    ExpenseMetricsGroupByEnum? groupBy,
  }) async {
    try {
      final query = <String, dynamic>{
        if (groupBy != null) 'group_by': groupBy.name,
        if (endDate != null) 'end_date': formatDateSerializer(endDate),
        if (startDate != null) 'start_date': formatDateSerializer(startDate),
      };
      final response = await _httpClient.get(
        parameter: Requests(
          path: HttpPathEnum.expenseMetrics.path,
          query: query.isEmpty ? null : query,
        ),
      );
      return ExpenseMetricsResponse.fromJson(
        response.body['data'] as Map<String, dynamic>,
      ).toEntity();
    } on HttpResponseException catch (exception) {
      throw MetricsException(errors: exception.errors.toEntity());
    } on HttpClientException {
      throw MetricsException(errors: .unknown());
    }
  }
}
