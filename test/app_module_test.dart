import 'package:mocktail/mocktail.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:intl/date_symbol_data_local.dart';

import 'support/core/mocks/http_client_mock.dart';

import 'package:cordato/app_module.dart';

import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_provider_widget.dart';

import 'package:cordato/features/settings/presentation/screens/settings/settings_screen.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/logout_bloc.dart';

import 'package:cordato/features/dashboard/presentation/screens/dashboard/bloc/dashboard_bloc.dart';

import 'package:cordato/features/authentication/presentation/screens/sign_in/sign_in_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/bloc/sign_up_bloc.dart';

import 'package:cordato/features/expense/presentation/screens/expense/expense_screen.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/expenses_screen.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_form_validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    registerFallbackValue(const Requests(path: ''));
    await initializeDateFormatting('pt_BR');
  });

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

  test('authentication and expense routes use root-owned module binds', () {
    final boot = bootstrapModule(appModule);
    addTearDown(boot.injector.dispose);
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
      final boot = bootstrapModule(appModule);
      addTearDown(boot.injector.dispose);
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

  testWidgets(
    'real app composition opens creation, editing, list and settings',
    (tester) async {
      final http = HttpClientMock();
      when(() => http.get(parameter: any(named: 'parameter')))
          .thenAnswer((invocation) async {
            final request = invocation.namedArguments[#parameter] as Requests;
            return Responses(
              status: 200,
              body: request.path == 'expenses'
                  ? {
                      'data': [],
                      'links': {'next': null, 'prev': null},
                    }
                  : {
                      'data': {
                        'id': '1',
                        'type': 'expenses',
                        'attributes': {
                          'amount': 1500,
                          'description': 'Mercado',
                          'occurred_on': '2026-09-03',
                          'category': 'food',
                        },
                      },
                    },
            );
          });
      final boot = bootstrapModule(appModule);
      boot.injector.replaceInstance<IHttpClient>(http);
      final router = modularRouterConfig(
        boot.routes,
        injector: boot.injector,
        manager: boot.manager,
        initialRoute: '/authentication/sign-in',
        defaultTransition: TransitionType.none,
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        (router.routerDelegate as ChangeNotifier).dispose();
        (router.routeInformationProvider as PlatformRouteInformationProvider)
            .dispose();
        boot.injector.dispose();
      });
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: Themes.light,
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (_, child) => ToastProviderWidget(child: child!),
        ),
      );
      await tester.pumpAndSettle();
      final signIn = tester
          .widget<SignInScreen>(find.byType(SignInScreen))
          .bloc;
      tester.element(find.byType(SignInScreen)).navigate('/expense');
      await tester.pumpAndSettle();
      expect(signIn.isClosed, isTrue);
      expect(find.byType(ExpenseScreen), findsOneWidget);
      expect(
        tester.widget<ExpenseScreen>(find.byType(ExpenseScreen)).id,
        isNull,
      );
      tester.element(find.byType(ExpenseScreen)).pushNamed('/expenses');
      await tester.pumpAndSettle();
      expect(find.byType(ExpensesScreen), findsOneWidget);
      tester
          .element(find.byType(ExpensesScreen))
          .pushNamed('/expense', arguments: '1');
      await tester.pumpAndSettle();
      expect(find.text('Mercado'), findsOneWidget);
      tester.element(find.byType(ExpenseScreen).last).navigate('/settings');
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
