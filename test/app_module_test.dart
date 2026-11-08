import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/app_module.dart';

import 'support/core/fakes/pocketbase_fixture.dart';

import 'package:cordato/features/root/presentation/bloc/home_widget_sync_bloc.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_launch_bloc.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/application/clients/interface_home_widget_client.dart';
import 'package:cordato/features/core/infrastructure/clients/home_widget/home_widget_client.dart';

import 'package:cordato/features/settings/presentation/screens/settings/bloc/logout_bloc.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/dashboard_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/bloc/sign_up_bloc.dart';

import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_form_validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Route catalog and dependency resolution', () {
    late ModularBootstrap boot;

    setUp(() {
      final fixture = PocketBaseFixture();
      addTearDown(fixture.client.close);
      boot = bootstrapModule(createAppModule(pocketBase: fixture.client));
      addTearDown(boot.injector.dispose);
    });

    test('application registers every navigation destination exactly once', () {
      for (final route in RouteEnum.values) {
        expect(
          boot.routes.routes.where(
            (registered) => registered.path == route.path,
          ),
          hasLength(1),
          reason: route.path,
        );
      }
    });

    test('widget launch observation resolves factory-owned Blocs without visiting routes', () async {
      final first = boot.injector.get<HomeWidgetLaunchBloc>();
      final second = boot.injector.get<HomeWidgetLaunchBloc>();

      expect(identical(first, second), isFalse);

      await first.close();
      await second.close();
    });

    test('home widget client resolves before any feature route is visited', () {
      final client = boot.injector.get<IHomeWidgetClient>();

      expect(client, isA<HomeWidgetClient>());
      expect(boot.injector.get<IHomeWidgetClient>(), same(client));
    });

    test(
      'widget synchronization resolves without visiting sibling routes',
      () async {
        final first = boot.injector.get<HomeWidgetSyncBloc>();
        final second = boot.injector.get<HomeWidgetSyncBloc>();

        expect(identical(first, second), isFalse);

        await first.close();
        await second.close();
      },
    );

    test('information destinations remain public in the full application', () {
      for (final destination in [
        RouteEnum.informationTerms,
        RouteEnum.informationPrivacy,
        RouteEnum.informationHelp,
      ]) {
        final matches = boot.routes.match(Uri.parse(destination.path));

        expect(destination.authenticated, isFalse);
        expect(matches, hasLength(1));
        expect(matches!.single.route.guards, isEmpty);
        expect(matches.single.route.provide, isNull);
        expect(matches.single.route.ownerTags, isEmpty);
      }
    });

    test(
      'dashboard resolves dependencies without visiting sibling routes',
      () async {
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
      final route = boot.routes.routes.singleWhere(
        (route) => route.path == RouteEnum.settings.path,
      );
      boot.manager.enter('settings', route.ownerTags);
      final bloc = boot.injector.get<LogoutBloc>();

      expect(bloc.isClosed, isFalse);

      await bloc.close();
      boot.manager.leave('settings', route.ownerTags);
    });

    test('authentication and expense routes use root-owned module binds', () {
      for (final path in ['/authentication/sign-in', '/expense', '/expenses']) {
        final route = boot.routes.routes.singleWhere(
          (route) => route.path == path,
        );
        expect(route.ownerTags, isEmpty);
      }
    });

    test(
      'expense and authentication factories resolve without activating routes',
      () async {
        final signUp = boot.injector.get<SignUpBloc>();
        final expense = boot.injector.get<ExpenseBloc>();
        final expenses = boot.injector.get<ExpensesBloc>();
        final validator = boot.injector.get<ExpenseFormValidator>();
        expect(
          validator(
            cents: 100,
            description: 'Mercado',
            occurredOn: DateTime.now(),
          ),
          isNotNull,
        );
        await signUp.close();
        expect(
          boot.injector.get<ExpenseFormValidator>(),
          isA<ExpenseFormValidator>(),
        );
        await expense.close();
        final otherList = boot.injector.get<ExpensesBloc>();
        expect(otherList, isNot(same(expenses)));
        await expenses.close();
        await otherList.close();
      },
    );
  });
}
