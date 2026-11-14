import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';
import 'package:cordato/features/metrics/presentation/widgets/expense_metrics_grid_widget.dart';
import 'package:cordato/features/metrics/presentation/extensions/expense_metrics_categories_extension.dart';
import 'package:cordato/features/metrics/presentation/mixins/expense_metrics_carousel_widget_state_mixin.dart';

final class const ExpenseMetricsCarouselWidget({
  super.key,
  required final IMoneyFormatter moneyFormatter,
  required final List<List<ExpenseCategoryMetricsEntity>> pages,
  final VoidCallback? onExpensesChanged,
  final ({DateTime from, DateTime to})? period,
}) extends StatefulWidget {
  @override
  State<ExpenseMetricsCarouselWidget> createState() =>
      _ExpenseMetricsCarouselWidgetState();
}

final class _ExpenseMetricsCarouselWidgetState
    extends State<ExpenseMetricsCarouselWidget>
    with ExpenseMetricsCarouselWidgetStateMixin {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        configureViewport(constraints.maxWidth);
        final pageWidth = constraints.maxWidth - 32.0;
        final layouts = widget.pages.indexed
            .map(
              (entry) => ExpenseMetricsGridWidget(
                categories: entry.$2,
                moneyFormatter: widget.moneyFormatter,
                showCategoryTip: widget.pages.showsCategoryTipAt(entry.$1),
              ).buildLayout(context, pageWidth),
            )
            .toList();
        final upperHeight = layouts
            .map((layout) => layout.upperHeight)
            .reduce(math.max);
        final lowerHeight = layouts[currentPage].lowerHeight;
        final pageHeight =
            upperHeight + (lowerHeight > 0 ? 12.0 + lowerHeight : 0.0);

        return Column(
          spacing: 24.0,
          children: [
            SizedBox(
              height: pageHeight,
              child: PageView.builder(
                controller: pageController,
                onPageChanged: onPageChanged,
                itemCount: widget.pages.length,
                itemBuilder: (_, index) => ExcludeSemantics(
                  excluding: index != currentPage,
                  child: OverflowBox(
                    minHeight: 0.0,
                    maxHeight: .infinity,
                    alignment: .topCenter,
                    child: Padding(
                      padding: const .symmetric(horizontal: 6.0),
                      child: ExpenseMetricsGridWidget(
                        period: widget.period,
                        upperHeight: upperHeight,
                        categories: widget.pages[index],
                        moneyFormatter: widget.moneyFormatter,
                        onExpensesChanged: widget.onExpensesChanged,
                        showCategoryTip: widget.pages.showsCategoryTipAt(index),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.pages.length > 1)
              Semantics(
                liveRegion: true,
                label:
                    'Página ${currentPage + 1} de ${widget.pages.length} de categorias',
                child: Row(
                  spacing: 6.0,
                  mainAxisAlignment: .center,
                  children: [
                    for (int index = 0; index < widget.pages.length; index++)
                      Container(
                        height: 6.0,
                        width: index == currentPage ? 16.0 : 6.0,
                        decoration: BoxDecoration(
                          borderRadius: context.radius.cornerRadiusFull,
                          color: index == currentPage
                              ? context.colors.primary
                              : context.colors.outlineVariant,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
