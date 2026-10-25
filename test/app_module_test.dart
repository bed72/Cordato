import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/app_module.dart';
import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/bloc/dashboard_bloc.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/logout_bloc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('application registers every navigation destination exactly once', () {
    final boot = bootstrapModule(appModule);
    addTearDown(boot.injector.dispose);

    for (final route in RouteEnum.values) {
      expect(
        boot.routes.routes.where((registered) => registered.path == route.path),
        hasLength(1),
        reason: route.path,
      );
    }
  });

  test(
    'dashboard resolves dependencies without visiting sibling routes',
    () async {
      final boot = bootstrapModule(appModule);
      addTearDown(boot.injector.dispose);
      final route = boot.routes.routes.singleWhere(
        (route) => route.path == RouteEnum.dashboard.path,
      );
      boot.manager.enter('dashboard', route.ownerTags);
      final first = boot.injector.get<DashboardBloc>();
      final second = boot.injector.get<DashboardBloc>();

      expect(identical(first, second), isFalse);

      await first.close();
      await second.close();
      boot.manager.leave('dashboard', route.ownerTags);
    },
  );

  test('logout resolves authentication outside its route scope', () async {
    final boot = bootstrapModule(appModule);
    addTearDown(boot.injector.dispose);
    final route = boot.routes.routes.singleWhere(
      (route) => route.path == RouteEnum.settings.path,
    );
    boot.manager.enter('settings', route.ownerTags);
    final bloc = boot.injector.get<LogoutBloc>();

    expect(bloc.isClosed, isFalse);

    await bloc.close();
    boot.manager.leave('settings', route.ownerTags);
  });
}
