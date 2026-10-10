import 'package:material_ui/material_ui.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';
import 'package:cordato/features/metrics/presentation/mixins/expense_metrics_chart_widget_state_mixin.dart';

final class const ExpenseMetricsChartWidget({
  super.key,
  required final IMoneyFormatter moneyFormatter,
  required final List<ExpenseCategoryMetricsEntity> categories,
}) extends StatefulWidget {
  @override
  State<ExpenseMetricsChartWidget> createState() =>
      _ExpenseMetricsChartWidgetState();
}

final class _ExpenseMetricsChartWidgetState
    extends State<ExpenseMetricsChartWidget>
    with ExpenseMetricsChartWidgetStateMixin {
  @override
  Widget build(BuildContext context) {
    return chartTotal <= 0
        ? const SizedBox.shrink()
        : Column(
            spacing: 8.0,
            crossAxisAlignment: .start,
            children: [_buildChart(), _buildSelection()],
          );
  }

  Widget _buildChart() => SizedBox(
    height: 44.0,
    child: BarChart(
      BarChartData(
        minY: 0,
        rotationQuarterTurns: 1,
        maxY: chartTotal.toDouble(),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        barGroups: [
          BarChartGroupData(
            x: 0,
            barRods: [
              BarChartRodData(
                toY: chartTotal.toDouble(),
                width: 36.0,
                rodStackItems: chartSegments,
                borderRadius: context.radius.cornerRadius100,
              ),
            ],
          ),
        ],
        barTouchData: BarTouchData(
          handleBuiltInTouches: false,
          touchCallback: onChartTouch,
        ),
      ),
      duration: MediaQuery.disableAnimationsOf(context)
          ? .zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    ),
  );

  Widget _buildSelection() => Semantics(
    container: true,
    liveRegion: true,
    excludeSemantics: true,
    label: selectedCategoryDetails,
    child: Row(
      spacing: 8.0,
      children: [
        Container(
          width: 8.0,
          height: 8.0,
          decoration: BoxDecoration(
            shape: .circle,
            color: selectedCategoryColor,
          ),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$selectedCategoryLabel · ',
                  style: TextStyle(
                    fontWeight: .w600,
                    color: context.colors.onSurface,
                  ),
                ),
                TextSpan(text: selectedCategoryAmount),
              ],
            ),
            style: context.typography.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}
