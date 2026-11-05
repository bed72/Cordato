sealed class HomeWidgetLaunchState {
  const HomeWidgetLaunchState();
}

final class const HomeWidgetLaunchInitial() extends HomeWidgetLaunchState;

final class const HomeWidgetLaunchListening() extends HomeWidgetLaunchState;

final class const HomeWidgetLaunchRequested({required final int sequence})
    extends HomeWidgetLaunchState;

final class const HomeWidgetLaunchFailure() extends HomeWidgetLaunchState;
