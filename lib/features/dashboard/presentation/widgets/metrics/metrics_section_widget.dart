import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/dashboard/presentation/widgets/metrics/animated_expense_total_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/metrics/mixins/metrics_section_state_mixin.dart';

import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/presentation/widgets/expense_metrics_carousel_widget.dart';
import 'package:cordato/features/metrics/presentation/widgets/expense_metrics_skeleton_widget.dart';
import 'package:cordato/features/metrics/presentation/extensions/expense_metrics_categories_extension.dart';

final class const MetricsSectionWidget({
  super.key,
  required final IMoneyFormatter moneyFormatter,
  required final ExpenseMetricsEntity? metrics,
}) extends StatefulWidget {
  @override
  State<MetricsSectionWidget> createState() => _MetricsSectionWidgetState();
}

final class _MetricsSectionWidgetState extends State<MetricsSectionWidget>
    with MetricsSectionStateMixin {
  @override
  Widget build(BuildContext context) {
    final metrics = widget.metrics;

    return Padding(
      padding: const .only(top: 8.0, bottom: 20.0),
      child: Column(
        spacing: 12.0,
        crossAxisAlignment: .start,
        children: [
          Padding(
            padding: const .symmetric(horizontal: 16.0),
            child: AnimatedExpenseTotalWidget(
              key: ObjectKey(metrics),
              isLoading: metrics == null,
              formatter: widget.moneyFormatter,
              cents: displayedTotalCents,
            ),
          ),
          _buildDistribution(metrics: metrics),
        ],
      ),
    );
  }

  Widget _buildDistribution({required ExpenseMetricsEntity? metrics}) {
    if (metrics == null) {
      return const Padding(
        padding: .symmetric(horizontal: 16.0),
        child: ExpenseMetricsSkeletonWidget(showTotal: false),
      );
    }

    final pages = metrics.categories?.cardPages ?? [];

    return switch ((metrics.totalAmount, pages)) {
      (0, _) => _buildMessage(
        message: 'Nenhuma despesa registrada neste período.',
      ),
      (_, []) => _buildMessage(
        message: 'A distribuição por categoria não está disponível.',
      ),
      (_, final pages) => ExpenseMetricsCarouselWidget(
        key: ObjectKey(metrics),
        pages: pages,
        moneyFormatter: widget.moneyFormatter,
        period: metricsPeriod,
        onExpensesChanged: expensesChangedCallback(),
      ),
    };
  }

  Padding _buildMessage({required String message}) => Padding(
    padding: const .symmetric(vertical: 12.0, horizontal: 16.0),
    child: Text(
      message,
      style: context.typography.bodyMedium?.copyWith(
        color: context.colors.onSurfaceVariant,
      ),
    ),
  );
}
