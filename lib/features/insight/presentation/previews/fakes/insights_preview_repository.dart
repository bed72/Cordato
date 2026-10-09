import 'package:cordato/features/insight/domain/repositories/interface_insight_repository.dart';

final class InsightsPreviewRepository({required final GetRepositoryType result})
    implements IInsightRepository {
  @override
  Future<GetRepositoryType> get() async => result;
}
