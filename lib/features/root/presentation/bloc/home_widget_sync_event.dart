sealed class HomeWidgetSyncEvent {
  const HomeWidgetSyncEvent();
}

final class const HomeWidgetSyncStartedEvent() extends HomeWidgetSyncEvent;

final class const HomeWidgetRefreshRequestedEvent() extends HomeWidgetSyncEvent;
