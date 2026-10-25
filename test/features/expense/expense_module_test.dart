import 'dart:async';

import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_repository.dart';
import 'package:cordato/features/expense/expense_module.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expense/expense_screen.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/expenses_screen.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expense_dismissible_widget.dart';
import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/formatters/date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_provider_widget.dart';

import '../../support/core/mocks/http_client_mock.dart';

void main() {
  setUpAll(() => registerFallbackValue(const Requests(path: '')));
  setUpAll(() => initializeDateFormatting('pt_BR'));

  test(
    'binds one HTTP-backed repository by contract without a data source',
    () async {
      final http = HttpClientMock();
      when(() => http.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Responses(
          status: 200,
          body: {
            'data': [],
            'links': {'next': null, 'prev': null},
          },
        ),
      );
      final boot = bootstrapModule(
        createModule(
          register: (context) {
            context.addInstance<IHttpClient>(http);
            context.module(expenseModule);
          },
        ),
      );
      addTearDown(boot.injector.dispose);
      final repository = inject<IExpenseRepository>();
      final form = inject<ExpenseBloc>();
      final otherForm = inject<ExpenseBloc>();
      final list = inject<ExpensesBloc>();
      final otherList = inject<ExpensesBloc>();
      expect(form, isNot(same(otherForm)));
      expect(list, isNot(same(otherList)));
      addTearDown(form.close);
      addTearDown(otherForm.close);
      addTearDown(list.close);
      addTearDown(otherList.close);
      expect(inject<IExpenseRepository>(), same(repository));
      expect((await repository.get(pageSize: 6)).items, isEmpty);
      final request =
          verify(() => http.get(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(request.path, 'expenses');
      expect(request.query, {'page[size]': 6});
      verifyNoMoreInteractions(http);
    },
  );

  testWidgets(
    'list route edits via a stable factory and returns the confirmed HTTP entity',
    (tester) async {
      final http = HttpClientMock();
      final date = DateTime.now().toIso8601String().split('T').first;
      Map<String, dynamic> resource(String description) => {
        'type': 'expenses',
        'id': '1',
        'attributes': {
          'amount': 1500,
          'description': description,
          'occurred_on': date,
          'category': 'food',
        },
      };
      when(() => http.get(parameter: any(named: 'parameter')))
          .thenAnswer((invocation) async {
            final request = invocation.namedArguments[#parameter] as Requests;
            return Responses(
              status: 200,
              body: request.path == 'expenses'
                  ? {
                      'data': [resource('Original')],
                      'links': {'next': null, 'prev': null},
                    }
                  : {'data': resource('Original')},
            );
          });
      final pending = Completer<Responses>();
      when(() => http.patch(parameter: any(named: 'parameter')))
          .thenAnswer((_) => pending.future);
      final boot = bootstrapModule(
        createModule(
          register: (context) {
            context
              ..addInstance<IHttpClient>(http)
              ..addInstance<IDateFormatter>(DateFormatter())
              ..addInstance<IMoneyFormatter>(MoneyFormatter())
              ..module(expenseModule);
          },
        ),
      );
      final router = modularRouterConfig(
        boot.routes,
        injector: boot.injector,
        manager: boot.manager,
        initialRoute: '/expenses',
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        if (!pending.isCompleted) {
          pending.complete(
            Responses(status: 200, body: {'data': resource('API')}),
          );
        }
        await tester.pumpAndSettle();
        (router.routerDelegate as ChangeNotifier).dispose();
        (router.routeInformationProvider as PlatformRouteInformationProvider)
            .dispose();
        boot.injector.dispose();
      });
      await tester.pumpWidget(
        MaterialApp.router(
          theme: Themes.light,
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: router,
          builder: (_, child) => ToastProviderWidget(child: child!),
        ),
      );
      await tester.pumpAndSettle();
      final listFactory = tester
          .widget<ExpensesScreen>(find.byType(ExpensesScreen))
          .bloc;
      tester.element(find.byType(ExpensesScreen)).markNeedsBuild();
      await tester.pump();
      expect(
        tester.widget<ExpensesScreen>(find.byType(ExpensesScreen)).bloc,
        listFactory,
      );
      unawaited(
        tester
            .widget<ExpenseDismissibleWidget>(
              find.byType(ExpenseDismissibleWidget),
            )
            .onEdit!(),
      );
      await tester.pumpAndSettle();
      final screen = tester.widget<ExpenseScreen>(find.byType(ExpenseScreen));
      expect(screen.id, '1');
      tester.element(find.byType(ExpenseScreen)).markNeedsBuild();
      await tester.pump();
      expect(
        tester.widget<ExpenseScreen>(find.byType(ExpenseScreen)).bloc,
        screen.bloc,
      );
      await tester.enterText(find.byType(TextField).first, '  Novo  ');
      await tester.pump();
      await tester.tap(find.text('Atualizar'));
      await tester.pump();
      await tester.pump();
      final request =
          verify(() => http.patch(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(request.path, 'expenses/1');
      expect(request.body, {
        'data': {
          'type': 'expenses',
          'attributes': {'description': 'Novo'},
        },
      });
      expect(find.byType(ExpenseScreen), findsOneWidget);
      pending.complete(
        Responses(status: 200, body: {'data': resource('Nome da API')}),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ExpenseScreen), findsNothing);
      expect(find.text('Nome da API'), findsOneWidget);
    },
  );
}
