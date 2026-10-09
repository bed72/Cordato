import 'package:cordato/features/insight/domain/entities/insight_period_entity.dart';
import 'package:cordato/features/insight/infrastructure/responses/insight_date_range_response.dart';

final class const InsightPeriodResponse({
  required final DateTime to,
  required final DateTime from,
  final InsightDateRangeResponse? comparison,
}) {
  factory InsightPeriodResponse.fromJson(Map<String, dynamic> json) {
    final comparison = json['comparison'] as Map<String, dynamic>?;

    return InsightPeriodResponse(
      from: DateTime.parse(json['from'] as String),
      to: DateTime.parse(json['to'] as String),
      comparison: comparison == null
          ? null
          : InsightDateRangeResponse.fromJson(comparison),
    );
  }
}

extension InsightPeriodResponseToEntity on InsightPeriodResponse {
  InsightPeriodEntity toEntity() => InsightPeriodEntity(
    to: to,
    from: from,
    comparison: comparison?.toEntity(),
  );
}
