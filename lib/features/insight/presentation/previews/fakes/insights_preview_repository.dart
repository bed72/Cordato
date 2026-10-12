import 'dart:async';

import 'package:cordato/features/insight/domain/repositories/interface_insight_repository.dart';

final class InsightsPreviewRepository({
  required final GetRepositoryType type,
  final bool loading = false,
}) implements IInsightRepository {
  @override
  Future<GetRepositoryType> get({int? year, int? month}) async =>
      loading ? Completer<GetRepositoryType>().future : type;
}
