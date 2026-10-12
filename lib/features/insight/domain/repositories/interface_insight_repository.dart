import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/insight/domain/entities/insight_entity.dart';

typedef GetRepositoryType = Either<ErrorsEntity, List<InsightEntity>>;

abstract interface class IInsightRepository {
  Future<GetRepositoryType> get({int? year, int? month});
}
