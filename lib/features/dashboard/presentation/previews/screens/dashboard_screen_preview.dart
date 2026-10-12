import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/formatters/date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/core/presentation/previews/preview_resource_widget.dart';

import 'package:cordato/features/user/presentation/screens/user/commands/user_command.dart';

import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/presentation/commands/get_expense_metrics_command.dart';
import 'package:cordato/features/metrics/presentation/previews/fakes/metrics_preview_repository.dart';

import 'package:cordato/features/insight/domain/entities/insight_entity.dart';
import 'package:cordato/features/insight/domain/entities/insight_period_entity.dart';
import 'package:cordato/features/insight/presentation/commands/get_insights_command.dart';
import 'package:cordato/features/insight/presentation/previews/fakes/insights_preview_repository.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/commands/get_expenses_command.dart';
import 'package:cordato/features/expense/presentation/previews/fakes/expenses_list_preview_repository.dart';

import 'package:cordato/features/dashboard/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:cordato/features/dashboard/presentation/previews/fakes/dashboard_user_preview_repository.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/commands/get_first_expense_month_command.dart';

@CordatoPreview(
  group: 'Dashboard / Telas',
  name: 'Contexto mensal / Claro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.light,
)
@CordatoPreview(
  group: 'Dashboard / Telas',
  name: 'Contexto mensal / Escuro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.dark,
)
Widget previewMonthlyDashboardScreen() => _screenPreview();

@CordatoPreview(
  group: 'Dashboard / Telas',
  name: 'Carregamento agregado',
  size: cordatoPhonePreviewSize,
)
Widget previewLoadingMonthlyDashboardScreen() => _screenPreview(loading: true);

@CordatoPreview(
  group: 'Dashboard / Telas',
  name: 'Mês vazio',
  size: cordatoPhonePreviewSize,
)
Widget previewEmptyMonthlyDashboardScreen() => _screenPreview(empty: true);

@CordatoPreview(
  group: 'Dashboard / Telas',
  name: 'Falha parcial de insights',
  size: cordatoPhonePreviewSize,
)
Widget previewPartialFailureMonthlyDashboardScreen() =>
    _screenPreview(failure: true);

Widget _screenPreview({
  bool empty = false,
  bool loading = false,
  bool failure = false,
}) {
  final today = DateTime.now();
  final month = DateTime(today.year, today.month);
  final end = DateTime(today.year, today.month + 1, 0);

  return PreviewResourceWidget<UserCommand>(
    create: () => UserCommand(repository: DashboardUserPreviewRepository()),
    dispose: (command) => command.dispose(),
    builder: (userCommand) => DashboardScreen(
      userCommand: userCommand,
      dateFormatter: DateFormatter(),
      moneyFormatter: MoneyFormatter(),
      firstExpenseMonthCommand: GetFirstExpenseMonthCommand(
        repository: ExpensesListPreviewRepository(
          loading: loading,
          items: empty
              ? []
              : [
                  ExpenseEntity(
                    id: 'first-expense',
                    category: .food,
                    description: 'Primeiro gasto',
                    cents: .create(cents: 1500).right,
                    occurredOn: DateTime(month.year, month.month - 2),
                  ),
                ],
        ),
      ),
      expensesCommand: GetExpensesCommand(
        repository: ExpensesListPreviewRepository(
          loading: loading,
          items: empty
              ? []
              : [
                  for (int index = 0; index < 6; index++)
                    ExpenseEntity(
                      id: 'monthly-$index',
                      category: .food,
                      description: 'Gasto do mês ${index + 1}',
                      cents: .create(cents: 1500 + index * 100).right,
                      occurredOn: DateTime(
                        month.year,
                        month.month,
                        today.day - index.clamp(0, today.day - 1),
                      ),
                    ),
                ],
        ),
      ),
      insightsCommand: GetInsightsCommand(
        repository: InsightsPreviewRepository(
          loading: loading,
          type: failure
              ? Left(ErrorsEntity.unknown())
              : Right(
                  empty
                      ? []
                      : [
                          InsightEntity(
                            id: 'monthly-insight',
                            group: 'comparison',
                            type: 'category_lead_streak',
                            title: 'Uma liderança recorrente',
                            description: 'Alimentação segue líder nos registros deste mês.',
                            period: InsightPeriodEntity(
                              to: end,
                              from: DateTime(month.year, month.month - 2),
                            ),
                          ),
                        ],
                ),
        ),
      ),
      metricsCommand: GetExpenseMetricsCommand(
        repository: MetricsPreviewRepository(
          loading: loading,
          type: empty
              ? Right(
                  ExpenseMetricsEntity(
                    id: 'empty-month',
                    endDate: end,
                    categories: [],
                    totalAmount: 0,
                    startDate: month,
                  ),
                )
              : null,
        ),
      ),
      onExpensePressed: () async {},
      onSeeAllExpensesPressed: (_) async {},
    ),
  );
}
