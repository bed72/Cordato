import 'package:cordato/features/insight/domain/entities/insight_date_range_entity.dart';

final class const InsightPeriodEntity({
  required final DateTime to,
  required final DateTime from,
  final InsightDateRangeEntity? comparison,
});
