import 'package:flutter_test/flutter_test.dart';
import 'package:cordato/features/root/presentation/navigation/home_widget_launch_policy.dart';
import 'package:cordato/features/session/presentation/bloc/session_state.dart';

void main() {
  final scenarios = <SessionState, HomeWidgetLaunchAction>{
    const SessionInitial(): .wait,
    const SessionLoading(): .wait,
    const SessionFailure(): .wait,
    const SessionUnauthenticated(): .signIn,
    const SessionAuthenticated(): .openExpense,
  };
  for (final scenario in scenarios.entries) {
    test('${scenario.key.runtimeType} chooses ${scenario.value.name}', () {
      expect(
        HomeWidgetLaunchPolicy.action(state: scenario.key, pending: true),
        scenario.value,
      );
    });
    test('${scenario.key.runtimeType} does nothing without an intent', () {
      expect(
        HomeWidgetLaunchPolicy.action(state: scenario.key, pending: false),
        HomeWidgetLaunchAction.wait,
      );
    });
  }
}
