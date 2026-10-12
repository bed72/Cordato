import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_path_enum.dart';

import 'package:cordato/features/insight/infrastructure/responses/insight_response.dart';

typedef GetDataSourceType = Either<ErrorsResponse, List<InsightResponse>>;

abstract interface class IInsightRemoteDataSource {
  Future<GetDataSourceType> get({int? year, int? month});
}

final class InsightRemoteDataSource({required final IHttpClient _client})
    implements IInsightRemoteDataSource {
  @override
  Future<GetDataSourceType> get({int? year, int? month}) => response(
    execute: () => _client.get(
      parameter: Requests(
        path: HttpPathEnum.insights.path,
        query: year == null && month == null
            ? null
            : {'filter[year]': ?year, 'filter[month]': ?month},
      ),
    ),
    from: (response) => (response.body['data'] as List<dynamic>)
        .map((item) => InsightResponse.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}
