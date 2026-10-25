import 'package:cordato/features/insight/domain/entities/insight_entity.dart';

abstract interface class IInsightRepository {
  Future<List<InsightEntity>> get({int? year, int? month});
}
