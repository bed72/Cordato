import 'package:cordato/features/insight/domain/entities/insight_date_range_entity.dart';

final class const InsightDateRangeResponse({
  required final DateTime to,
  required final DateTime from,
}) {
  factory InsightDateRangeResponse.fromJson(Map<String, dynamic> json) =>
      InsightDateRangeResponse(
        from: DateTime.parse(json['from'] as String),
        to: DateTime.parse(json['to'] as String),
      );
}

extension InsightDateRangeResponseToEntity on InsightDateRangeResponse {
  InsightDateRangeEntity toEntity() =>
      InsightDateRangeEntity(from: from, to: to);
}
