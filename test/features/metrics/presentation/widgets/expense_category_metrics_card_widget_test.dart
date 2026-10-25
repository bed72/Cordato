import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/presentation/formatters/date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_provider_widget.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/expenses_screen.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expenses_app_bar_widget.dart';
import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';
import 'package:cordato/features/metrics/presentation/widgets/expense_category_metrics_card_widget.dart';

import '../../../../support/expense/mocks/expense_repository_mock.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  for (final systemBack in [false, true]) {
    testWidgets('refreshes after ${systemBack ? 'system' : 'app bar'} back', (
      tester,
    ) async {
      final repository = ExpenseRepositoryMock();
      final from = DateTime(2026, 9);
      final to = DateTime(2026, 9, 30);
      when(
        () =>
            repository.get(pageSize: 20, from: from, to: to, category: 'food'),
      ).thenAnswer(
        (_) async => ExpensePageEntity(items: [], next: null, prev: null),
      );
      int refreshes = 0;
      ExpensesBloc? owner;
      final module = createModule(
        register: (context) => context
          ..route(
            '/',
            child: (_, _) => Scaffold(
              body: ExpenseCategoryMetricsCardWidget(
                moneyFormatter: MoneyFormatter(),
                category: const ExpenseCategoryMetricsEntity(
                  category: 'food',
                  totalAmount: 1500,
                  percentage: 100,
                ),
                period: (from: from, to: to),
                onExpensesChanged: () => refreshes++,
              ),
            ),
          )
          ..route(
            '/expenses',
            child: (_, state) {
              expect(state.arguments, (from: from, to: to, category: 'food'));
              return ExpensesScreen(
                bloc: () => owner = ExpensesBloc(repository: repository),
                dateFormatter: DateFormatter(),
                moneyFormatter: MoneyFormatter(),
                period: (from: from, to: to),
                category: 'food',
              );
            },
          ),
      );
      await tester.pumpWidget(
        ModularApp(
          module: module,
          defaultTransition: TransitionType.none,
          child: Builder(
            builder: (context) => MaterialApp.router(
              routerConfig: ModularApp.routerConfigOf(context),
              theme: Themes.light,
              locale: const Locale('pt', 'BR'),
              supportedLocales: const [Locale('pt', 'BR')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              builder: (_, child) => ToastProviderWidget(child: child!),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ExpenseCategoryMetricsCardWidget));
      await tester.pumpAndSettle();
      expect(find.byType(ExpensesScreen), findsOneWidget);
      expect(refreshes, 0);

      if (systemBack) {
        await tester.binding.handlePopRoute();
      } else {
        tester
            .widget<ExpensesAppBarWidget>(find.byType(ExpensesAppBarWidget))
            .onBackPressed();
      }
      await tester.pumpAndSettle();
      expect(find.byType(ExpensesScreen), findsNothing);
      expect(refreshes, 1);
      expect(owner!.isClosed, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
