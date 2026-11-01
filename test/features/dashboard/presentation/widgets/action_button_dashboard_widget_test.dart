import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/bloc/dashboard_bloc.dart';
import 'package:cordato/features/dashboard/presentation/widgets/action_button_dashboard_widget.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/user/domain/entities/user_entity.dart';

import '../../../../support/expense/mocks/expense_repository_mock.dart';
import '../../../../support/metrics/mocks/metrics_repository_mock.dart';
import '../../../../support/user/mocks/user_repository_mock.dart';

void main() {
  for (final saved in [false, true]) {
    testWidgets(
      'Dashboard ${saved ? 'reloads on confirmed expense result' : 'does not reload on cancellation'}',
      (tester) async {
        final expenses = ExpenseRepositoryMock();
        final users = UserRepositoryMock();
        final metrics = MetricsRepositoryMock();
        final page = ExpensePageEntity(items: [], next: null, prev: null);
        when(() => users.getById()).thenAnswer(
          (_) async => const UserEntity(
            id: '1',
            name: 'Pessoa',
            email: 'person@example.com',
            status: 'active',
          ),
        );
        when(() => expenses.get(pageSize: 1, sort: 'occurred_on'))
            .thenAnswer((_) async => page);
        when(
          () => expenses.get(
            pageSize: 6,
            from: any(named: 'from'),
            to: any(named: 'to'),
          ),
        ).thenAnswer((_) async => page);
        when(
          () => metrics.getExpenses(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
            groupBy: .category,
          ),
        ).thenAnswer(
          (_) async => ExpenseMetricsEntity(
            id: '1',
            startDate: DateTime.now(),
            endDate: DateTime.now(),
            totalAmount: 0,
            categories: [],
          ),
        );
        final bloc = DashboardBloc(
          userRepository: users,
          expenseRepository: expenses,
          metricsRepository: metrics,
        );
        final expense = ExpenseEntity(
          id: '1',
          description: 'Confirmado',
          cents: .create(cents: 100),
          occurredOn: DateTime.now(),
          category: .food,
        );
        Object? arguments;
        final boot = bootstrapModule(
          createModule(
            register: (context) {
              context
                ..route(
                  '/dashboard',
                  child: (_, _) => BlocProvider.value(
                    value: bloc,
                    child: const Scaffold(
                      floatingActionButton: ActionButtonDashboardWidget(),
                    ),
                  ),
                )
                ..route(
                  '/expense',
                  child: (context, state) {
                    arguments = state.arguments;
                    return Scaffold(
                      body: TextButton(
                        onPressed: () => context.pop(saved ? expense : null),
                        child: const Text('Voltar'),
                      ),
                    );
                  },
                );
            },
          ),
        );
        final router = modularRouterConfig(
          boot.routes,
          injector: boot.injector,
          manager: boot.manager,
          initialRoute: '/dashboard',
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await bloc.close();
          (router.routerDelegate as ChangeNotifier).dispose();
          (router.routeInformationProvider as PlatformRouteInformationProvider)
              .dispose();
          boot.injector.dispose();
        });
        await tester.pumpWidget(
          MaterialApp.router(theme: Themes.light, routerConfig: router),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Adicionar gasto'));
        await tester.pumpAndSettle();
        expect(arguments, (returnToPrevious: true));
        verifyZeroInteractions(users);
        await tester.tap(find.text('Voltar'));
        await tester.pumpAndSettle();
        if (saved) {
          verify(() => users.getById()).called(1);
        } else {
          verifyZeroInteractions(users);
          verifyZeroInteractions(expenses);
          verifyZeroInteractions(metrics);
        }
        expect(find.byTooltip('Adicionar gasto'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
