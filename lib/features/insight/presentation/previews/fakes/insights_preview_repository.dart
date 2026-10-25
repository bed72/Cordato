import 'dart:async';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/insight/application/exceptions/insight_exception.dart';
import 'package:cordato/features/insight/application/repositories/interface_insight_repository.dart';
import 'package:cordato/features/insight/domain/entities/insight_entity.dart';

final class InsightsPreviewRepository({
  final List<InsightEntity> data = const [],
  final ErrorsEntity? failure,
  final bool loading = false,
}) implements IInsightRepository {
  @override
  Future<List<InsightEntity>> get({int? year, int? month}) async {
    if (loading) return Completer<List<InsightEntity>>().future;
    if (failure case final errors?) throw InsightException(errors: errors);
    return data;
  }
}
