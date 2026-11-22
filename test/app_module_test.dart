import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:localstore/localstore.dart';

import 'package:cordato/app_module.dart';
import 'package:cordato/features/core/infrastructure/clients/widget_client.dart';
import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/dashboard_bloc.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/dashboard_event.dart';
import 'package:cordato/features/dashboard/presentation/enums/dashboard_phase_enum.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_repository.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_form_validator.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_bloc.dart';
import 'package:cordato/features/metrics/application/repositories/interface_metrics_repository.dart';
import 'package:cordato/features/root/application/repositories/interface_widget_sync_repository.dart';
import 'package:cordato/features/root/presentation/bloc/widget_launch_bloc.dart';
import 'package:cordato/features/root/presentation/bloc/widget_sync_bloc.dart';
import 'package:cordato/features/user/application/repositories/interface_user_repository.dart';

import 'support/core/storage/localstore_test_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Local route catalog and dependency resolution', () {
    final storage = LocalstoreTestStorage();
    late ModularBootstrap boot;

    setUpAll(storage.open);
    tearDownAll(storage.close);

    setUp(() async {
      await storage.initialize();
      addTearDown(storage.clear);
      boot = bootstrapModule(appModule);
      addTearDown(boot.injector.dispose);
    });

    test('registers each current destination exactly once without authentication routes', () {
      final destinations = [
        RouteEnum.app,
        RouteEnum.dashboard,
        RouteEnum.user,
        RouteEnum.userEdit,
        RouteEnum.expense,
        RouteEnum.expenses,
        RouteEnum.settings,
        RouteEnum.settingsSupport,
        RouteEnum.informationTerms,
        RouteEnum.informationPrivacy,
        RouteEnum.informationHelp,
      ];

      expect(
        boot.routes.routes.map((route) => route.path),
        unorderedEquals(destinations.map((route) => route.path)),
      );
      for (final destination in destinations) {
        expect(
          boot.routes.match(Uri.parse(destination.path)),
          hasLength(1),
          reason: destination.path,
        );
        expect(destination.authenticated, isFalse);
      }
    });

    test('shares the ready database before visiting any feature', () {
      expect(boot.injector.get<Localstore>(), same(storage.database));
      expect(boot.injector.get<Localstore>(), same(storage.database));
    });

    test('root registration does not take ownership of the database', () async {
      boot.injector.dispose();

      expect(
        (await storage.database
            .collection('user')
            .doc('profile')
            .get())!['name'],
        'Cordato',
      );
    });

    test('Metrics reads Expense writes and Root refreshes through the local composition', () async {
      const channel = MethodChannel('home_widget');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final expenses = boot.injector.get<IExpenseRepository>();
      final metrics = boot.injector.get<IMetricsRepository>();
      final synchronization = boot.injector.get<IWidgetSyncRepository>();
      expect(boot.injector.get<IMetricsRepository>(), same(metrics));
      await storage.expense(
        () => expenses.create(
          cents: 123,
          description: 'Mercado',
          category: .food,
        ),
      );

      final monthly = await metrics.getExpenses(groupBy: .category);
      expect(monthly.total, 123);
      expect(monthly.categories!.single.category, 'food');

      await synchronization.enable();
      await synchronization.refresh();

      final saved = calls.singleWhere(
        (call) => call.method == 'saveWidgetData',
      );
      final arguments = saved.arguments as Map;
      final now = DateTime.now();
      expect(arguments['id'], 'monthly_summary');
      expect(jsonDecode(arguments['data'] as String), {
        'month': '${now.year}-${now.month.toString().padLeft(2, '0')}',
        'cents': 123,
      });
      expect(calls.last.method, 'updateWidget');
    });

    test('Dashboard loads locally persisted metrics without visiting Expense or User', () async {
      await storage.expense(
        () => boot.injector.get<IExpenseRepository>().create(
          cents: 321,
          description: 'Mercado',
          category: .food,
        ),
      );
      final route = boot.routes.routes.singleWhere(
        (route) => route.path == RouteEnum.dashboard.path,
      );
      boot.manager.enter('dashboard-metrics-test', route.ownerTags);
      addTearDown(
        () => boot.manager.leave('dashboard-metrics-test', route.ownerTags),
      );
      final bloc = boot.injector.get<DashboardBloc>();
      addTearDown(bloc.close);
      final loaded = bloc.stream.firstWhere(
        (state) => state.phase == .ready || state.phase == .failure,
      );

      bloc.add(DashboardOpened());
      final dashboard = await loaded;

      expect(dashboard.phase, DashboardPhaseEnum.ready);
      expect(dashboard.metrics!.total, 321);
      expect(dashboard.metrics!.categories!.single.category, 'food');
      expect(dashboard.expenses!.items.single.cents.cents, 321);
    });

    test(
      'widget launch observation resolves independent factory-owned Blocs',
      () {
        final first = boot.injector.get<WidgetLaunchBloc>();
        addTearDown(first.close);
        final second = boot.injector.get<WidgetLaunchBloc>();
        addTearDown(second.close);

        expect(first, isNot(same(second)));
      },
    );

    test(
      'native widget client resolves before any feature route is visited',
      () {
        final client = boot.injector.get<IWidgetClient>();

        expect(client, isA<WidgetClient>());
        expect(boot.injector.get<IWidgetClient>(), same(client));
      },
    );

    test('widget synchronization resolves without visiting sibling routes', () {
      final first = boot.injector.get<WidgetSyncBloc>();
      addTearDown(first.close);
      final second = boot.injector.get<WidgetSyncBloc>();
      addTearDown(second.close);

      expect(first, isNot(same(second)));
    });

    test(
      'Information and Settings remain public without a page-owned Bloc',
      () {
        for (final destination in [
          RouteEnum.informationTerms,
          RouteEnum.informationPrivacy,
          RouteEnum.informationHelp,
          RouteEnum.settings,
          RouteEnum.settingsSupport,
        ]) {
          final matches = boot.routes.match(Uri.parse(destination.path));

          expect(matches, hasLength(1));
          expect(matches!.single.route.guards, isEmpty);
          expect(matches.single.route.provide, isNull);
          expect(matches.single.route.ownerTags, isEmpty);
        }
      },
    );

    test(
      'Dashboard resolves independent Bloc factories without sibling routes',
      () {
        final route = boot.routes.routes.singleWhere(
          (route) => route.path == RouteEnum.dashboard.path,
        );
        boot.manager.enter('dashboard-test', route.ownerTags);
        addTearDown(
          () => boot.manager.leave('dashboard-test', route.ownerTags),
        );
        final first = boot.injector.get<DashboardBloc>();
        addTearDown(first.close);
        final second = boot.injector.get<DashboardBloc>();
        addTearDown(second.close);

        expect(first, isNot(same(second)));
      },
    );

    test(
      'profile and expenses are available before visiting their routes',
      () async {
        final user = boot.injector.get<IUserRepository>();
        final expenses = boot.injector.get<IExpenseRepository>();

        expect((await user.get()).name, 'Cordato');
        final created = await storage.expense(
          () => expenses.create(cents: 100, description: 'Mercado'),
        );
        expect((await expenses.getById(id: created.id)).description, 'Mercado');
        expect(boot.injector.get<IUserRepository>(), same(user));
        expect(boot.injector.get<IExpenseRepository>(), same(expenses));
      },
    );

    test(
      'Expense keeps root-owned binds and independent form/list factories',
      () {
        for (final destination in [RouteEnum.expense, RouteEnum.expenses]) {
          final route = boot.routes.routes.singleWhere(
            (route) => route.path == destination.path,
          );
          expect(route.ownerTags, isEmpty);
        }
        final form = boot.injector.get<ExpenseBloc>();
        addTearDown(form.close);
        final otherForm = boot.injector.get<ExpenseBloc>();
        addTearDown(otherForm.close);
        final list = boot.injector.get<ExpensesBloc>();
        addTearDown(list.close);
        final otherList = boot.injector.get<ExpensesBloc>();
        addTearDown(otherList.close);

        expect(form, isNot(same(otherForm)));
        expect(list, isNot(same(otherList)));
        expect(
          boot.injector.get<ExpenseFormValidator>(),
          isA<ExpenseFormValidator>(),
        );
      },
    );
  });
}
