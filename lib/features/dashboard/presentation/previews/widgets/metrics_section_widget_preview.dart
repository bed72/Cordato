import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/formatters/date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/core/presentation/previews/preview_resource_widget.dart';

import 'package:cordato/features/dashboard/presentation/widgets/metrics/metrics_section_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/dashboard_month_selector_widget.dart';

import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';

import 'package:cordato/features/metrics/presentation/bloc/expense_metrics_bloc.dart';
import 'package:cordato/features/metrics/presentation/bloc/expense_metrics_event.dart';
import 'package:cordato/features/metrics/presentation/bloc/expense_metrics_state.dart';
import 'package:cordato/features/metrics/presentation/previews/fakes/metrics_preview_repository.dart';

@CordatoPreview(
  group: 'Metrics / Cards',
  name: 'Categorias / Claro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.light,
)
@CordatoPreview(
  group: 'Metrics / Cards',
  name: 'Categorias / Escuro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.dark,
)
Widget previewMetricsSectionWidget() => _sectionPreview();

@CordatoPreview(
  group: 'Metrics / Cards',
  name: 'Carregando',
  size: cordatoPhonePreviewSize,
)
Widget previewLoadingExpenseMetricsCardsWidget() =>
    _sectionPreview(loading: true);

@CordatoPreview(
  group: 'Metrics / Cards',
  name: 'Sem gastos',
  size: Size(390, 380),
)
Widget previewEmptyExpenseMetricsCardsWidget() => _sectionPreview(month: 9);

@CordatoPreview(
  group: 'Dashboard / Período',
  name: 'Fevereiro bissexto',
  size: Size(390, 340),
)
Widget previewLeapFebruaryDashboardMonth() =>
    _sectionPreview(year: 2024, month: 2);

@CordatoPreview(
  group: 'Dashboard / Período',
  name: 'Virada de ano',
  size: Size(390, 340),
)
Widget previewYearBoundaryDashboardMonth() => _sectionPreview(month: 1);

@CordatoPreview(
  group: 'Metrics / Cards',
  name: 'Empates e categorias novas / Estreito',
  size: Size(320, 440),
)
Widget previewManyExpenseMetricsCategories() => _sectionPreview(
  data: ExpenseMetricsEntity(
    id: 'many-categories',
    totalAmount: 100000,
    endDate: DateTime(2026, 10, 31),
    startDate: DateTime(2026, 10, 1),
    categories: [
      for (final category in [
        'food',
        'health',
        'housing',
        'services',
        'transport',
        'education',
        'subscriptions',
        'future_category',
      ])
        ExpenseCategoryMetricsEntity(
          category: category,
          percentage: 12.50,
          totalAmount: 12500,
        ),
    ],
  ),
);

@CordatoPreview(
  group: 'Metrics / Cards',
  name: 'Texto ampliado',
  size: Size(390, 520),
)
Widget previewLargeTextExpenseMetricsCardsWidget() => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(1.6)),
    child: _sectionPreview(data: _categoriesResult(8, large: true)),
  ),
);

@CordatoPreview(
  group: 'Metrics / Quantidades',
  name: '1 categoria',
  size: cordatoPhonePreviewSize,
)
Widget previewOneMetricsCategory() =>
    _sectionPreview(data: _categoriesResult(1));

@CordatoPreview(
  group: 'Metrics / Quantidades',
  name: '2 categorias',
  size: cordatoPhonePreviewSize,
)
@CordatoPreview(
  group: 'Metrics / Quantidades',
  name: '2 categorias / Escuro / Card inferior largo',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.dark,
)
Widget previewTwoMetricsCategories() =>
    _sectionPreview(data: _categoriesResult(2));

@CordatoPreview(
  group: 'Metrics / Quantidades',
  name: '3 categorias',
  size: cordatoPhonePreviewSize,
)
Widget previewThreeMetricsCategories() =>
    _sectionPreview(data: _categoriesResult(3));

@CordatoPreview(
  group: 'Metrics / Quantidades',
  name: '4 categorias / Última página com dica',
  size: cordatoPhonePreviewSize,
)
Widget previewFourMetricsCategories() =>
    _sectionPreview(data: _categoriesResult(4));

@CordatoPreview(
  group: 'Metrics / Quantidades',
  name: '5 categorias / Última página com dois cards largos',
  size: cordatoPhonePreviewSize,
)
Widget previewFiveMetricsCategories() =>
    _sectionPreview(data: _categoriesResult(5));

@CordatoPreview(
  group: 'Metrics / Quantidades',
  name: '6 categorias / Duas páginas completas',
  size: cordatoPhonePreviewSize,
)
Widget previewSixMetricsCategories() =>
    _sectionPreview(data: _categoriesResult(6));

@CordatoPreview(
  group: 'Metrics / Quantidades',
  name: '10 categorias / Última página com dica',
  size: cordatoPhonePreviewSize,
)
Widget previewTenMetricsCategories() =>
    _sectionPreview(data: _categoriesResult(10));

@CordatoPreview(
  group: 'Metrics / Quantidades',
  name: '7 categorias',
  size: cordatoPhonePreviewSize,
)
Widget previewSevenMetricsCategories() =>
    _sectionPreview(data: _categoriesResult(7));

@CordatoPreview(
  group: 'Metrics / Quantidades',
  name: '8 categorias / Claro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.light,
)
@CordatoPreview(
  group: 'Metrics / Quantidades',
  name: '8 categorias / Escuro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.dark,
)
Widget previewEightMetricsCategories() =>
    _sectionPreview(data: _categoriesResult(8));

@CordatoPreview(
  group: 'Metrics / Cards',
  name: 'Distribuição indisponível após filtro',
  size: cordatoPhonePreviewSize,
)
Widget previewFilteredMetricsCategories() => _sectionPreview(
  data: ExpenseMetricsEntity(
    id: 'filtered',
    totalAmount: 10000,
    startDate: DateTime(2026, 10),
    endDate: DateTime(2026, 10, 31),
    categories: const [
      ExpenseCategoryMetricsEntity(
        category: 'food',
        totalAmount: 0,
        percentage: 0,
      ),
    ],
  ),
);

@CordatoPreview(
  group: 'Metrics / Cards',
  name: 'Texto ampliado / Escuro',
  size: Size(320, 844),
  brightness: Brightness.dark,
)
Widget previewDarkLargeTextMetricsCards() => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: const TextScaler.linear(2.0),
      disableAnimations: true,
    ),
    child: _sectionPreview(data: _categoriesResult(7, large: true)),
  ),
);

ExpenseMetricsEntity _categoriesResult(int count, {bool large = false}) =>
    ExpenseMetricsEntity(
      id: 'categories-$count',
      startDate: DateTime(2026, 10),
      endDate: DateTime(2026, 10, 31),
      totalAmount: large ? 99999999999 : 360000,
      categories: [
        for (final (index, category) in [
          'food',
          'pets',
          'other',
          'housing',
          'personal_care',
          'gifts_and_donations',
          'Categoria futura com nome extenso',
          'subscriptions',
          'health',
          'transport',
        ].take(count).indexed)
          ExpenseCategoryMetricsEntity(
            category: category,
            totalAmount: large
                ? 9999999999 - index
                : index < 8
                ? 80000 - index * 10000
                : 5000 - (index - 8) * 1000,
            percentage: 23.45 - index * 2,
          ),
      ],
    );

Widget _sectionPreview({
  int month = 10,
  int year = 2026,
  bool loading = false,
  ExpenseMetricsEntity? data,
}) {
  return PreviewResourceWidget<
    ({ExpenseMetricsBloc bloc, ValueNotifier<DateTime> month})
  >(
    create: () {
      final selectedMonth = DateTime(year, month, 1);
      final bloc = ExpenseMetricsBloc(
        repository: MetricsPreviewRepository(
          data: data,
          delay: const Duration(milliseconds: 250),
        ),
      );
      if (!loading) {
        bloc.add(
          ExpenseMetricsRequestedEvent(
            startDate: selectedMonth,
            endDate: DateTime(year, month + 1, 0),
            groupBy: .category,
          ),
        );
      }
      return (bloc: bloc, month: ValueNotifier(selectedMonth));
    },
    dispose: (resource) {
      resource.bloc.close();
      resource.month.dispose();
    },
    builder: (resource) => StatefulBuilder(
      builder: (context, setState) {
        final bloc = resource.bloc;
        final selectedMonth = resource.month.value;
        void load() => bloc.add(
          ExpenseMetricsRequestedEvent(
            startDate: resource.month.value,
            endDate: DateTime(
              resource.month.value.year,
              resource.month.value.month + 1,
              0,
            ),
            groupBy: .category,
          ),
        );
        void changeMonth(int offset) {
          if (bloc.state.isLoading) return;
          setState(
            () => resource.month.value = DateTime(
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
              child: Column(
                children: [
                  BlocBuilder<ExpenseMetricsBloc, ExpenseMetricsState>(
                    bloc: bloc,
                    builder: (_, state) => DashboardMonthSelectorWidget(
                      formatter: DateFormatter(),
                      selectedMonth: selectedMonth,
                      onPreviousMonth: loading || state.isLoading
                          ? null
                          : () => changeMonth(-1),
                      onNextMonth:
                          loading ||
                              state.isLoading ||
                              !selectedMonth.isBefore(
                                DateTime(
                                  DateTime.now().year,
                                  DateTime.now().month,
                                ),
                              )
                          ? null
                          : () => changeMonth(1),
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  BlocBuilder<ExpenseMetricsBloc, ExpenseMetricsState>(
                    bloc: bloc,
                    builder: (_, state) => MetricsSectionWidget(
                      metrics: state.metrics,
                      moneyFormatter: MoneyFormatter(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
