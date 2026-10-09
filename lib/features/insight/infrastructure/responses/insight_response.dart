import 'package:cordato/features/insight/domain/entities/insight_entity.dart';
import 'package:cordato/features/insight/infrastructure/responses/insight_period_response.dart';

final class const InsightResponse({
  required final String id,
  required final String type,
  required final String title,
  required final String group,
  required final String description,
  required final InsightPeriodResponse? period,
}) {
  factory InsightResponse.fromJson(Map<String, dynamic> json) {
    final root = json['attributes'] as Map<String, dynamic>;
    final period = root['period'] as Map<String, dynamic>?;

    return InsightResponse(
      id: json['id'] as String,
      type: root['type'] as String,
      title: root['title'] as String,
      group: root['group'] as String,
      description: root['description'] as String,
      period: period == null ? null : .fromJson(period),
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
    period: period?.toEntity(),
  );
}
