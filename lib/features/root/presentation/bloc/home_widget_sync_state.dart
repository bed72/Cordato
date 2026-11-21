import 'package:cordato/features/core/domain/entities/errors_entity.dart';

sealed class HomeWidgetSyncState {
  const HomeWidgetSyncState();
}

final class const HomeWidgetSyncInitial() extends HomeWidgetSyncState;

final class const HomeWidgetSyncUpdating() extends HomeWidgetSyncState;

final class const HomeWidgetSyncReady() extends HomeWidgetSyncState;

final class const HomeWidgetSyncFailure({required final ErrorsEntity errors})
    extends HomeWidgetSyncState;
