import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/formatters/date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/previews/preview_resource_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/metrics/metrics_section_widget.dart';
import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';
import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/domain/repositories/interface_metrics_repository.dart';
import 'package:cordato/features/metrics/presentation/commands/get_expense_metrics_command.dart';
import 'package:cordato/features/metrics/presentation/previews/fakes/metrics_preview_repository.dart';

@CordatoPreview(
  group: 'Metrics / Gráfico',
  name: 'Categorias / Claro',
  size: Size(390, 340),
  brightness: Brightness.light,
)
@CordatoPreview(
  group: 'Metrics / Gráfico',
  name: 'Categorias / Escuro',
  size: Size(390, 340),
  brightness: Brightness.dark,
)
Widget previewMetricsSectionWidget() => _sectionPreview();

@CordatoPreview(
  group: 'Metrics / Gráfico',
  name: 'Carregando',
  size: Size(390, 300),
)
Widget previewLoadingExpenseMetricsChartWidget() =>
    _sectionPreview(loading: true);

@CordatoPreview(
  group: 'Metrics / Gráfico',
  name: 'Sem gastos',
  size: Size(390, 380),
)
Widget previewEmptyExpenseMetricsChartWidget() => _sectionPreview(month: 9);

@CordatoPreview(
  group: 'Metrics / Gráfico',
  name: 'Erro com retry',
  size: Size(390, 340),
)
Widget previewFailureExpenseMetricsChartWidget() =>
    _sectionPreview(result: Left(ErrorsEntity.unknown()));

@CordatoPreview(
  group: 'Metrics / Gráfico',
  name: 'Categorias novas',
  size: Size(320, 440),
)
Widget previewManyExpenseMetricsCategories() => _sectionPreview(
  result: Right(
    ExpenseMetricsEntity(
      id: 'many-categories',
      totalAmount: 100000,
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 31),
      categories: [
        for (final category in [
          'housing',
          'food',
          'health',
          'transport',
          'subscriptions',
          'education',
          'services',
          'future_category',
        ])
          ExpenseCategoryMetricsEntity(
            category: category,
            totalAmount: 12500,
            percentage: 12.50,
          ),
      ],
    ),
  ),
);

@CordatoPreview(
  group: 'Metrics / Gráfico',
  name: 'Texto ampliado',
  size: Size(390, 520),
)
Widget previewLargeTextExpenseMetricsChartWidget() => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(1.6)),
    child: _sectionPreview(),
  ),
);

Widget _sectionPreview({
  GetExpensesRepositoryType? result,
  bool loading = false,
  int month = 10,
}) {
  DateTime selectedMonth = DateTime(2026, month, 1);
  return PreviewResourceWidget<GetExpenseMetricsCommand>(
    create: () {
      final command = GetExpenseMetricsCommand(
        repository: MetricsPreviewRepository(
          result: result,
          delay: const Duration(milliseconds: 250),
        ),
      );
      if (!loading) {
        command.execute.run((
          startDate: selectedMonth,
          endDate: DateTime(2026, month + 1, 0),
          groupBy: .category,
        ));
      }
      return command;
    },
    dispose: (command) => command.dispose(),
    builder: (command) => StatefulBuilder(
      builder: (context, setState) {
        void load() => command.execute.run((
          startDate: selectedMonth,
          endDate: DateTime(selectedMonth.year, selectedMonth.month + 1, 0),
          groupBy: .category,
        ));
        void changeMonth(int offset) {
          if (command.execute.isRunning.value) return;
          setState(
            () => selectedMonth = DateTime(
              selectedMonth.year,
              selectedMonth.month + offset,
            ),
          );
          load();
        }

        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: MetricsSectionWidget(
                command: command,
                selectedMonth: selectedMonth,
                dateFormatter: DateFormatter(),
                moneyFormatter: MoneyFormatter(),
                onPreviousMonth: () => changeMonth(-1),
                onNextMonth: () => changeMonth(1),
                onRetry: load,
              ),
            ),
          ),
        );
      },
    ),
  );
}
