import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';

import 'package:cordato/features/insight/infrastructure/responses/insight_response.dart';
import 'package:cordato/features/insight/domain/repositories/interface_insight_repository.dart';
import 'package:cordato/features/insight/infrastructure/remoto/insight_remote_data_source.dart';

final class InsightRepository({
  required final IInsightRemoteDataSource _remoteDataSource,
}) implements IInsightRepository {
  @override
  Future<GetRepositoryType> get({int? year, int? month}) async {
    try {
      final response = await _remoteDataSource.get(year: year, month: month);

      return response.either(
        (errors) => errors.toEntity(),
        (insights) => insights.map((insight) => insight.toEntity()).toList(),
      );
    } catch (_) {
      return Left(.unknown());
    }
  }
}
