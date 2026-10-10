import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/metrics/domain/enums/expense_metrics_group_by_enum.dart';
import 'package:cordato/features/metrics/domain/repositories/interface_metrics_repository.dart';
import 'package:cordato/features/metrics/infrastructure/remoto/metrics_remote_data_source.dart';
import 'package:cordato/features/metrics/infrastructure/responses/expense_metrics_response.dart';

final class MetricsRepository({
  required final IMetricsRemoteDataSource _remoteDataSource,
}) implements IMetricsRepository {
  @override
  Future<GetExpensesRepositoryType> getExpenses({
    DateTime? endDate,
    DateTime? startDate,
    ExpenseMetricsGroupByEnum? groupBy,
  }) async {
    try {
      final response = await _remoteDataSource.getExpenses(
        groupBy: groupBy,
        endDate: endDate,
        startDate: startDate,
      );

      return response.either(
        (errors) => errors.toEntity(),
        (metrics) => metrics.toEntity(),
      );
    } catch (_) {
      return Left(.unknown());
    }
  }
}
