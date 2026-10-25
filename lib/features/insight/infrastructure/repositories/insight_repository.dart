import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_path_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';

import 'package:cordato/features/insight/domain/entities/insight_entity.dart';
import 'package:cordato/features/insight/infrastructure/responses/insight_response.dart';

import 'package:cordato/features/insight/application/exceptions/insight_exception.dart';
import 'package:cordato/features/insight/application/repositories/interface_insight_repository.dart';

final class InsightRepository({required final IHttpClient _httpClient})
    implements IInsightRepository {
  @override
  Future<List<InsightEntity>> get({int? year, int? month}) async {
    try {
      final response = await _httpClient.get(
        parameter: Requests(
          path: HttpPathEnum.insights.path,
          query: year == null && month == null
              ? null
              : {'filter[year]': ?year, 'filter[month]': ?month},
        ),
      );

      return (response.body['data'] as List<dynamic>)
          .map(
            (item) =>
                InsightResponse.fromJson(item as Map<String, dynamic>)
                    .toEntity(),
          )
          .toList();
    } on HttpResponseException catch (exception) {
      throw InsightException(errors: exception.errors.toEntity());
    } on HttpClientException {
      throw InsightException(errors: .unknown());
    }
  }
}
