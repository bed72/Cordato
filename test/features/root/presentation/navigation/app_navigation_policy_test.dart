import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/root/presentation/navigation/app_navigation_policy.dart';

void main() {
  test('ordinary root entry opens Dashboard without session validation', () {
    expect(RouteEnum.dashboard.authenticated, isFalse);
    expect(
      AppNavigationPolicy.action(
        path: RouteEnum.app.path,
        pendingExpense: false,
      ),
      AppNavigationAction.dashboard,
    );
  });

  for (final destination in [
    RouteEnum.dashboard,
    RouteEnum.user,
    RouteEnum.userEdit,
    RouteEnum.expense,
    RouteEnum.expenses,
    RouteEnum.settings,
    RouteEnum.settingsSupport,
    RouteEnum.informationHelp,
    RouteEnum.informationTerms,
    RouteEnum.informationPrivacy,
  ]) {
    test('startup preserves an existing ${destination.name} destination', () {
      expect(
        AppNavigationPolicy.action(
          path: destination.path,
          pendingExpense: false,
        ),
        AppNavigationAction.none,
      );
    });

    test('widget intent takes precedence over ${destination.name}', () {
      expect(
        AppNavigationPolicy.action(
          path: destination.path,
          pendingExpense: true,
        ),
        AppNavigationAction.newExpense,
      );
    });
  }

  test(
    'a widget launch at root opens creation rather than ordinary startup',
    () {
      expect(
        AppNavigationPolicy.action(
          path: RouteEnum.app.path,
          pendingExpense: true,
        ),
        AppNavigationAction.newExpense,
      );
    },
  );
}
