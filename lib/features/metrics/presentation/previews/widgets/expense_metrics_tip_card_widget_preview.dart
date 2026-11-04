import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';

import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';
import 'package:cordato/features/metrics/presentation/widgets/expense_metrics_grid_widget.dart';
import 'package:cordato/features/metrics/presentation/widgets/expense_metrics_tip_card_widget.dart';
import 'package:cordato/features/metrics/presentation/extensions/expense_metrics_categories_extension.dart';

@CordatoPreview(
  group: 'Metrics / Dica',
  name: 'Card informativo / Claro',
  size: Size(390.0, 240.0),
  brightness: Brightness.light,
)
@CordatoPreview(
  group: 'Metrics / Dica',
  name: 'Card informativo / Escuro',
  size: Size(390.0, 240.0),
  brightness: Brightness.dark,
)
Widget previewExpenseMetricsTipCardWidget() => const Scaffold(
  body: SafeArea(
    child: SingleChildScrollView(
      padding: .all(20.0),
      child: ExpenseMetricsTipCardWidget(),
    ),
  ),
);

@CordatoPreview(
  group: 'Metrics / Dica',
  name: '4 categorias / Última página / Claro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.light,
)
@CordatoPreview(
  group: 'Metrics / Dica',
  name: '4 categorias / Última página / Escuro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.dark,
)
Widget previewFourCategoriesLastPageWithTip() => _lastPage(4);

@CordatoPreview(
  group: 'Metrics / Dica',
  name: '7 categorias / Última página',
  size: cordatoPhonePreviewSize,
)
Widget previewSevenCategoriesLastPageWithTip() => _lastPage(7);

@CordatoPreview(
  group: 'Metrics / Dica',
  name: '10 categorias / Última página',
  size: cordatoPhonePreviewSize,
)
Widget previewTenCategoriesLastPageWithTip() => _lastPage(10);

@CordatoPreview(
  group: 'Metrics / Dica',
  name: 'Última página / Estreito e texto ampliado',
  size: Size(320.0, 844.0),
  brightness: Brightness.dark,
)
Widget previewLargeTextLastPageWithTip() => _lastPage(4, textScale: 2.0);

Widget _lastPage(int count, {double textScale = 1.0}) {
  final pages = [
    for (final (index, category) in [
      'housing',
      'food',
      'transport',
      'pets',
      'health',
      'education',
      'services',
      'subscriptions',
      'personal_care',
      'other',
    ].take(count).indexed)
      ExpenseCategoryMetricsEntity(
        category: category,
        totalAmount: 12000 - index * 1000,
        percentage: 18.0 - index,
      ),
  ].cardPages;

  return Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const .all(20.0),
            child: ExpenseMetricsGridWidget(
              categories: pages.last,
              showCategoryTip: pages.showsCategoryTipAt(pages.length - 1),
              moneyFormatter: MoneyFormatter(),
            ),
          ),
        ),
      ),
    ),
  );
}
