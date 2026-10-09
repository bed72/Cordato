import 'package:cordato/features/insight/domain/entities/insight_entity.dart';
import 'package:cordato/features/insight/infrastructure/responses/insight_period_response.dart';

final class const InsightResponse({
  required final String id,
  required final String type,
  required final String title,
  required final String group,
  required final String description,
  required final InsightPeriodResponse period,
}) {
  factory InsightResponse.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>;

    return InsightResponse(
      id: json['id'] as String,
      title: attributes['title'] as String,
      type: attributes['type'] as String,
      group: attributes['group'] as String,
      description: attributes['description'] as String,
      period: InsightPeriodResponse.fromJson(
        attributes['period'] as Map<String, dynamic>,
      ),
    );
  }
}

extension InsightResponseToEntity on InsightResponse {
  InsightEntity toEntity() => InsightEntity(
    id: id,
    type: type,
    title: title,
    group: group,
    description: description,
    period: period.toEntity(),
  );
}
