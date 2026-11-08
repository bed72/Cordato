import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/formatters/date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/core/presentation/previews/preview_resource_widget.dart';

import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/presentation/previews/fakes/metrics_preview_repository.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/presentation/previews/fakes/expenses_list_preview_repository.dart';

import 'package:cordato/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/dashboard_bloc.dart';
import 'package:cordato/features/dashboard/presentation/previews/fakes/dashboard_user_preview_repository.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/speech_bloc.dart';
import 'package:cordato/features/dashboard/presentation/previews/fakes/speech_preview_repository.dart';

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
  name: 'Primeiro gasto / Claro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.light,
)
@CordatoPreview(
  group: 'Dashboard / Telas',
  name: 'Primeiro gasto / Escuro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.dark,
)
Widget previewFirstExpenseDashboardScreen() => _screenPreview(empty: true);

@CordatoPreview(
  group: 'Dashboard / Telas',
  name: 'Mês vazio com histórico',
  size: cordatoPhonePreviewSize,
)
Widget previewEmptyMonthlyDashboardScreen() =>
    _screenPreview(empty: true, hasHistory: true);

@CordatoPreview(
  group: 'Dashboard / Telas',
  name: 'Primeiro gasto / Texto ampliado',
  size: Size(320.0, 568.0),
)
Widget previewLargeTextEmptyDashboardScreen() => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(2)),
    child: _screenPreview(empty: true),
  ),
);

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
  bool hasHistory = false,
  bool loading = false,
  bool failure = false,
  bool userFailure = false,
}) {
  final today = DateTime.now();
  final month = DateTime(today.year, today.month);
  final end = DateTime(today.year, today.month + 1, 0);

  return PreviewResourceWidget<SpeechBloc>(
    create: () => SpeechBloc(repository: SpeechPreviewRepository()),
    dispose: (bloc) => bloc.close(),
    builder: (speechBloc) => DashboardScreen(
      speechBloc: speechBloc,
      dateFormatter: DateFormatter(),
      moneyFormatter: MoneyFormatter(),
      dashboardBloc: () => DashboardBloc(
        userRepository: DashboardUserPreviewRepository(
          failure: userFailure ? ErrorsEntity.unknown() : null,
        ),
        expenseRepository: ExpensesListPreviewRepository(
          loading: loading,
          items: empty
              ? [
                  if (hasHistory)
                    ExpenseEntity(
                      category: .food,
                      cents: .create(cents: 1500),
                      id: 'previous-month-expense',
                      description: 'Gasto do mês anterior',
                      occurredOn: DateTime(month.year, month.month - 1, 15),
                    ),
                ]
              : [
                  for (int index = 0; index < 6; index++)
                    ExpenseEntity(
                      id: 'monthly-$index',
                      category: .food,
                      description: 'Gasto do mês ${index + 1}',
                      cents: .create(cents: 1500 + index * 100),
                      occurredOn: DateTime(
                        month.year,
                        month.month,
                        today.day - index.clamp(0, today.day - 1),
                      ),
                    ),
                ],
        ),
        metricsRepository: MetricsPreviewRepository(
          loading: loading,
          failure: failure ? ErrorsEntity.unknown() : null,
          data: empty
              ? ExpenseMetricsEntity(
                  id: 'empty-month',
                  endDate: end,
                  categories: [],
                  totalAmount: 0,
                  startDate: month,
                )
              : null,
        ),
      ),
    ),
  );
}
