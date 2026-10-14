import 'package:command_it/command_it.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/presentation/commands/get_expense_metrics_command.dart';
import 'package:cordato/features/metrics/presentation/widgets/expense_metrics_carousel_widget.dart';
import 'package:cordato/features/metrics/presentation/widgets/expense_metrics_skeleton_widget.dart';
import 'package:cordato/features/metrics/presentation/extensions/expense_metrics_categories_extension.dart';

final class const MetricsSectionWidget({
  super.key,
  required final IMoneyFormatter moneyFormatter,
  required final GetExpenseMetricsCommand command,
  final ValueChanged<String>? onCategoryPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CommandBuilder(
      command: command.execute,
      whileRunning: (_, _, _) => _buildSection(
        context: context,
        child: const ExpenseMetricsSkeletonWidget(),
      ),
      onError: (_, _, _, _) => const SizedBox.shrink(),
      onData: (_, metrics, _) => Padding(
        padding: const .only(top: 8.0, bottom: 20.0),
        child: _buildMetrics(context: context, metrics: metrics!),
      ),
      onNullData: (_, _) => _buildSection(
        context: context,
        child: const ExpenseMetricsSkeletonWidget(),
      ),
    );
  }

  Padding _buildSection({
    required BuildContext context,
    required Widget child,
  }) => Padding(padding: const .fromLTRB(20.0, 8.0, 20.0, 20.0), child: child);

  Column _buildMetrics({
    required BuildContext context,
    required ExpenseMetricsEntity metrics,
  }) {
    final pages = metrics.categories?.cardPages ?? [];

    return Column(
      spacing: 12.0,
      crossAxisAlignment: .start,
      children: [
        Padding(
          padding: const .symmetric(horizontal: 20.0),
          child: Semantics(
            excludeSemantics: true,
            label:
                'Total de gastos: ${moneyFormatter.formatCents(metrics.totalAmount)}',
            child: Text(
              moneyFormatter.formatCents(metrics.totalAmount),
              style: context.typography.headlineMedium?.copyWith(
                fontWeight: .w600,
                letterSpacing: -1.0,
              ),
            ),
          ),
        ),
        switch ((metrics.totalAmount, pages)) {
          (0, _) => _buildMessage(
            context: context,
            message: 'Nenhuma despesa registrada neste período.',
          ),
          (_, [])
              when metrics.categories?.any(
                    (category) => category.totalAmount > 0,
                  ) ??
                  false =>
            const SizedBox.shrink(),
          (_, []) => _buildMessage(
            context: context,
            message: 'A distribuição por categoria não está disponível.',
          ),
          (_, final pages) => ExpenseMetricsCarouselWidget(
            key: ObjectKey(metrics),
            pages: pages,
            moneyFormatter: moneyFormatter,
            onCategoryPressed: onCategoryPressed,
          ),
        },
      ],
    );
  }

  Padding _buildMessage({
    required BuildContext context,
    required String message,
  }) => Padding(
    padding: const .symmetric(vertical: 12.0, horizontal: 20.0),
    child: Text(
      message,
      style: context.typography.bodyMedium?.copyWith(
        color: context.colors.onSurfaceVariant,
      ),
    ),
  );
}
