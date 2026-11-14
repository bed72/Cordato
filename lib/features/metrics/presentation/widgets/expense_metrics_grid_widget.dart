import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';
import 'package:cordato/features/metrics/presentation/widgets/expense_category_card_widget.dart';
import 'package:cordato/features/metrics/presentation/widgets/expense_metrics_tip_card_widget.dart';

final class const ExpenseMetricsGridWidget({
  super.key,
  required final IMoneyFormatter moneyFormatter,
  required final List<ExpenseCategoryMetricsEntity> categories,
  final double? upperHeight,
  final VoidCallback? onExpensesChanged,
  final ({DateTime from, DateTime to})? period,
  final bool showCategoryTip = false,
}) extends StatelessWidget {
  bool get hasCategoryTip => showCategoryTip && categories.length == 1;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = buildLayout(context, constraints.maxWidth);
        final topHeight = math.max(layout.upperHeight, upperHeight ?? 0.0);
        final bottomHeight = layout.lowerHeight;

        return Column(
          spacing: 12.0,
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            SizedBox(
              height: topHeight,
              child: ExpenseCategoryCardWidget(
                compact: true,
                period: period,
                highlighted: true,
                formatter: moneyFormatter,
                category: categories.first,
                onExpensesChanged: onExpensesChanged,
              ),
            ),
            if (categories.length > 1)
              SizedBox(
                height: bottomHeight,
                child: Row(
                  spacing: 12.0,
                  crossAxisAlignment: .stretch,
                  children: [
                    for (final category in categories.skip(1))
                      Expanded(
                        child: ExpenseCategoryCardWidget(
                          period: period,
                          category: category,
                          formatter: moneyFormatter,
                          illustrated: categories.length == 2,
                          onExpensesChanged: onExpensesChanged,
                        ),
                      ),
                  ],
                ),
              ),
            if (hasCategoryTip)
              SizedBox(
                height: bottomHeight,
                child: const ExpenseMetricsTipCardWidget(),
              ),
          ],
        );
      },
    );
  }

  ({double upperHeight, double lowerHeight, double height}) buildLayout(
    BuildContext context,
    double width,
  ) {
    final heights = [
      for (final (index, category) in categories.indexed)
        ExpenseCategoryCardWidget(
          compact: true,
          category: category,
          highlighted: index == 0,
          formatter: moneyFormatter,
        ).buildHeightFor(
          context: context,
          category: category,
          highlighted: index == 0,
          formatter: moneyFormatter,
          width: index == 0 || categories.length == 2
              ? width
              : (width - 12.0) / 2.0,
        ),
    ];
    final topHeight = heights.first;
    final bottomHeight = hasCategoryTip
        ? math.max(
            topHeight,
            const ExpenseMetricsTipCardWidget().buildHeightFor(
              context: context,
              width: width,
            ),
          )
        : heights.skip(1).fold(0.0, math.max);

    return (
      upperHeight: topHeight,
      lowerHeight: bottomHeight,
      height:
          topHeight +
          (categories.length > 1 || hasCategoryTip ? 12.0 + bottomHeight : 0.0),
    );
  }
}
