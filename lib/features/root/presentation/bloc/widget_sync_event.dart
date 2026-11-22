sealed class WidgetSyncEvent {
  const WidgetSyncEvent();
}

final class const WidgetSyncStartedEvent() extends WidgetSyncEvent;

final class const WidgetRefreshRequestedEvent() extends WidgetSyncEvent;
