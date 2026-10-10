import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_path_enum.dart';
import 'package:cordato/features/core/infrastructure/serializers/civil_date_serializer.dart';

import 'package:cordato/features/metrics/domain/enums/expense_metrics_group_by_enum.dart';
import 'package:cordato/features/metrics/infrastructure/responses/expense_metrics_response.dart';

typedef GetExpensesDataSourceType =
    Either<ErrorsResponse, ExpenseMetricsResponse>;

abstract interface class IMetricsRemoteDataSource {
  Future<GetExpensesDataSourceType> getExpenses({
    DateTime? endDate,
    DateTime? startDate,
    ExpenseMetricsGroupByEnum? groupBy,
  });
}

final class MetricsRemoteDataSource({required final IHttpClient _client})
    implements IMetricsRemoteDataSource {
  @override
  Future<GetExpensesDataSourceType> getExpenses({
    DateTime? endDate,
    DateTime? startDate,
    ExpenseMetricsGroupByEnum? groupBy,
  }) => response(
    execute: () {
      final query = <String, dynamic>{
        if (groupBy != null) 'group_by': groupBy.name,
        if (endDate != null) 'end_date': formatDateSerializer(endDate),
        if (startDate != null) 'start_date': formatDateSerializer(startDate),
      };

      return _client.get(
        parameter: Requests(
          query: query.isEmpty ? null : query,
          path: HttpPathEnum.expenseMetrics.path,
        ),
      );
    },
    from: (response) =>
        .fromJson(response.body['data'] as Map<String, dynamic>),
  );
}
