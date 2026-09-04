import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/enums/route_enum.dart';
import 'package:cordato/features/dashboard/dashboard_module.dart';

void main() {
  test('registers the dashboard route', () {
    final rootModule = createModule(
      register: (context) => context.module(dashboardModule),
    );
    final bootstrap = bootstrapModule(rootModule);

    final route = bootstrap.routes.match(Uri.parse(RouteEnum.dashboard.path));

    expect(route, isNotNull);
    expect(route!.last.route.path, RouteEnum.dashboard.path);

    bootstrap.manager.root.disposeRecursive();
  });
}
