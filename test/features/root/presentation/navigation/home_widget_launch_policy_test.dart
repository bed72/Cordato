import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/root/presentation/navigation/home_widget_launch_policy.dart';
import 'package:cordato/features/session/presentation/bloc/session_state.dart';

void main() {
  group('Widget launch URI', () {
    test('accepts only the native add-expense action', () {
      expect(
        HomeWidgetLaunchPolicy.accepts(
          Uri.parse('cordato://widget/add-expense?homeWidget=true'),
        ),
        isTrue,
      );
    });

    for (final address in [
      null,
      'https://widget/add-expense?homeWidget=true',
      'cordato://other/add-expense?homeWidget=true',
      'cordato://widget/edit-expense?homeWidget=true',
      'cordato://widget/add-expense',
      'cordato://widget/add-expense?homeWidget=false',
      'cordato://widget/add-expense?homeWidget=true&homeWidget=true',
      'cordato://widget/add-expense?homeWidget=true&token=untrusted',
      'cordato://user@widget/add-expense?homeWidget=true',
      'cordato://widget:123/add-expense?homeWidget=true',
      'cordato://widget/add-expense?homeWidget=true#extra',
    ]) {
      test('ignores $address', () {
        expect(
          HomeWidgetLaunchPolicy.accepts(
            address == null ? null : Uri.parse(address),
          ),
          isFalse,
        );
      });
    }
  });

  group('Session and pending intent', () {
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
          HomeWidgetLaunchPolicy.action(
            state: scenario.key,
            pending: true,
            deferred: false,
          ),
          scenario.value,
        );
      });

      test('${scenario.key.runtimeType} does nothing without an intent', () {
        expect(
          HomeWidgetLaunchPolicy.action(
            state: scenario.key,
            pending: false,
            deferred: false,
          ),
          HomeWidgetLaunchAction.wait,
        );
      });

      test('${scenario.key.runtimeType} respects redirect deferral', () {
        expect(
          HomeWidgetLaunchPolicy.action(
            state: scenario.key,
            pending: true,
            deferred: true,
          ),
          HomeWidgetLaunchAction.wait,
        );
      });
    }
  });
}
