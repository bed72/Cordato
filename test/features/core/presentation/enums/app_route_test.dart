import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';

void main() {
  test('exposes the local application route paths without authentication', () {
    expect(RouteEnum.app.path, '/');
    expect(RouteEnum.welcome.path, '/welcome');
    expect(RouteEnum.dashboard.path, '/dashboard');
    expect(RouteEnum.user.path, '/user');
    expect(RouteEnum.userEdit.path, '/user/edit');
    expect(RouteEnum.expense.path, '/expense');
    expect(RouteEnum.expenses.path, '/expenses');
    expect(RouteEnum.settings.path, '/settings');
    expect(RouteEnum.settingsSupport.path, '/settings/support');
    expect(RouteEnum.authenticatedPaths(), isEmpty);
  });
}
