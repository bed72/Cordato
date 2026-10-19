import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/formatters/date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';

import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/presentation/previews/fakes/metrics_preview_repository.dart';

import 'package:cordato/features/insight/domain/entities/insight_entity.dart';
import 'package:cordato/features/insight/domain/entities/insight_period_entity.dart';
import 'package:cordato/features/insight/presentation/previews/fakes/insights_preview_repository.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/presentation/previews/fakes/expenses_list_preview_repository.dart';

import 'package:cordato/features/dashboard/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/bloc/dashboard_bloc.dart';
import 'package:cordato/features/dashboard/presentation/previews/fakes/dashboard_user_preview_repository.dart';

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
  name: 'Erro financeiro global / Claro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.light,
)
@CordatoPreview(
  group: 'Dashboard / Telas',
  name: 'Erro financeiro global / Escuro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.dark,
)
Widget previewPartialFailureMonthlyDashboardScreen() =>
    _screenPreview(failure: true);

@CordatoPreview(
  group: 'Dashboard / Telas',
  name: 'Fallback do usuário / Claro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.light,
)
@CordatoPreview(
  group: 'Dashboard / Telas',
  name: 'Fallback do usuário / Escuro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.dark,
)
Widget previewDashboardUserFallback() => _screenPreview(userFailure: true);

Widget _screenPreview({
  bool empty = false,
  bool loading = false,
  bool failure = false,
  bool userFailure = false,
}) {
  final today = DateTime.now();
  final month = DateTime(today.year, today.month);
  final end = DateTime(today.year, today.month + 1, 0);

  return DashboardScreen(
    dateFormatter: DateFormatter(),
    moneyFormatter: MoneyFormatter(),
    bloc: () => DashboardBloc(
      userRepository: DashboardUserPreviewRepository(
        failure: userFailure ? ErrorsEntity.unknown() : null,
      ),
      expenseRepository: ExpensesListPreviewRepository(
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
      insightRepository: InsightsPreviewRepository(
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
      metricsRepository: MetricsPreviewRepository(
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
  );
}
