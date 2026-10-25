import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/insight/domain/entities/insight_entity.dart';

sealed class InsightsState {
  const InsightsState();

  bool get isLoading => this is InsightsLoading;

  List<InsightEntity>? get insights => switch (this) {
    InsightsSuccess(:final data) => data,
    _ => null,
  };
}

final class const InsightsInitial() extends InsightsState {}

final class const InsightsLoading() extends InsightsState {}

final class InsightsSuccess({required List<InsightEntity> data})
    extends InsightsState {
  final List<InsightEntity> data = .unmodifiable(data);
}

final class const InsightsFailure({required final ErrorsEntity errors})
    extends InsightsState {}
