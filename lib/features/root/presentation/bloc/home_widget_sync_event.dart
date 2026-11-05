sealed class HomeWidgetSyncEvent {
  const HomeWidgetSyncEvent();
}

sealed class HomeWidgetSyncOperationEvent extends HomeWidgetSyncEvent {
  const HomeWidgetSyncOperationEvent();
}

final class const HomeWidgetSyncStartedEvent() extends HomeWidgetSyncEvent;

final class const HomeWidgetSessionChangedEvent({
  required final bool authenticated,
}) extends HomeWidgetSyncOperationEvent;

final class const HomeWidgetRefreshRequestedEvent()
    extends HomeWidgetSyncOperationEvent;
