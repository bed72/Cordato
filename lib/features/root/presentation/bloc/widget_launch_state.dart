sealed class WidgetLaunchState {
  const WidgetLaunchState();
}

final class const WidgetLaunchInitial() extends WidgetLaunchState;

final class const WidgetLaunchListening() extends WidgetLaunchState;

final class const WidgetLaunchRequested({required final int sequence})
    extends WidgetLaunchState;

final class const WidgetLaunchFailure() extends WidgetLaunchState;
