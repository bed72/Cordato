import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';
import 'package:cordato/features/metrics/presentation/widgets/expense_category_metrics_card_widget.dart';

final class const ExpenseMetricsGridWidget({
  super.key,
  required final IMoneyFormatter moneyFormatter,
  required final List<ExpenseCategoryMetricsEntity> categories,
  final ValueChanged<String>? onCategoryPressed,
  final double? upperHeight,
  final double? lowerHeight,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = buildLayout(context, constraints.maxWidth);
        final topHeight = math.max(layout.upperHeight, upperHeight ?? 0.0);
        final bottomHeight = math.max(layout.lowerHeight, lowerHeight ?? 0.0);

        return Column(
          spacing: 12.0,
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            SizedBox(
              height: topHeight,
              child: ExpenseCategoryMetricsCardWidget(
                compact: true,
                highlighted: true,
                category: categories.first,
                onTap: onCategoryPressed == null
                    ? null
                    : () => onCategoryPressed!(categories.first.category),
                moneyFormatter: moneyFormatter,
              ),
            ),
            SizedBox(
              height: bottomHeight,
              child: Row(
                spacing: 12.0,
                crossAxisAlignment: .stretch,
                children: [
                  for (final category in categories.skip(1))
                    Expanded(
                      child: ExpenseCategoryMetricsCardWidget(
                        category: category,
                        onTap: onCategoryPressed == null
                            ? null
                            : () => onCategoryPressed!(category.category),
                        moneyFormatter: moneyFormatter,
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

  ({double upperHeight, double lowerHeight, double height}) buildLayout(
    BuildContext context,
    double width,
  ) {
    final heights = [
      for (final (index, category) in categories.indexed)
        ExpenseCategoryMetricsCardWidget(
          compact: true,
          category: category,
          highlighted: index == 0,
          moneyFormatter: moneyFormatter,
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
    final bottomHeight = heights.skip(1).reduce(math.max);

    return (
      upperHeight: topHeight,
      lowerHeight: bottomHeight,
      height: topHeight + 12.0 + bottomHeight,
    );
  }
}
