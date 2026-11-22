import 'package:cordato/features/core/domain/entities/errors_entity.dart';

sealed class WidgetSyncState {
  const WidgetSyncState();
}

final class const WidgetSyncInitial() extends WidgetSyncState;

final class const WidgetSyncUpdating() extends WidgetSyncState;

final class const WidgetSyncReady() extends WidgetSyncState;

final class const WidgetSyncFailure({required final ErrorsEntity errors})
    extends WidgetSyncState;
