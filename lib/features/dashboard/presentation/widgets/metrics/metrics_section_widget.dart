import 'package:command_it/command_it.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/dashboard/presentation/widgets/metrics/animated_expense_total_widget.dart';

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
}) extends StatefulWidget {
  @override
  State<MetricsSectionWidget> createState() => _MetricsSectionWidgetState();
}

final class _MetricsSectionWidgetState extends State<MetricsSectionWidget> {
  int? _previousTotalCents;
  int? _initialTotalCents;
  ({DateTime from, DateTime to})? _previousPeriod;

  @override
  void initState() {
    super.initState();
    widget.command.execute.results.addListener(_rememberTotal);
    _rememberTotal();
  }

  @override
  void didUpdateWidget(covariant MetricsSectionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.command, widget.command)) return;

    oldWidget.command.execute.results.removeListener(_rememberTotal);
    _previousTotalCents = null;
    _initialTotalCents = null;
    _previousPeriod = null;
    widget.command.execute.results.addListener(_rememberTotal);
    _rememberTotal();
  }

  @override
  void dispose() {
    widget.command.execute.results.removeListener(_rememberTotal);
    super.dispose();
  }

  void _rememberTotal() {
    final result = widget.command.execute.results.value;
    if (result.isRunning || result.hasError || result.data == null) return;

    final metrics = result.data!;
    final period = (
      from: DateTime(
        metrics.startDate.year,
        metrics.startDate.month,
        metrics.startDate.day,
      ),
      to: DateTime(
        metrics.endDate.year,
        metrics.endDate.month,
        metrics.endDate.day,
      ),
    );
    _initialTotalCents = _previousPeriod == period ? _previousTotalCents : null;
    _previousTotalCents = metrics.totalAmount;
    _previousPeriod = period;
  }

  @override
  Widget build(BuildContext context) {
    return CommandBuilder(
      command: widget.command.execute,
      whileRunning: (_, _, _) =>
          _buildSection(child: const ExpenseMetricsSkeletonWidget()),
      onError: (_, _, _, _) => const SizedBox.shrink(),
      onData: (_, metrics, _) => Padding(
        padding: const .only(top: 8.0, bottom: 20.0),
        child: _buildMetrics(metrics: metrics!),
      ),
      onNullData: (_, _) =>
          _buildSection(child: const ExpenseMetricsSkeletonWidget()),
    );
  }

  Padding _buildSection({required Widget child}) =>
      Padding(padding: const .fromLTRB(20.0, 8.0, 20.0, 20.0), child: child);

  Column _buildMetrics({required ExpenseMetricsEntity metrics}) {
    final pages = metrics.categories?.cardPages ?? [];

    return Column(
      spacing: 12.0,
      crossAxisAlignment: .start,
      children: [
        Padding(
          padding: const .symmetric(horizontal: 20.0),
          child: AnimatedExpenseTotalWidget(
            key: ObjectKey(metrics),
            cents: metrics.totalAmount,
            formatter: widget.moneyFormatter,
            initialCents: _initialTotalCents,
          ),
        ),
        switch ((metrics.totalAmount, pages)) {
          (0, _) => _buildMessage(
            message: 'Nenhuma despesa registrada neste período.',
          ),
          (_, [])
              when metrics.categories?.any(
                    (category) => category.totalAmount > 0,
                  ) ??
                  false =>
            const SizedBox.shrink(),
          (_, []) => _buildMessage(
            message: 'A distribuição por categoria não está disponível.',
          ),
          (_, final pages) => ExpenseMetricsCarouselWidget(
            key: ObjectKey(metrics),
            pages: pages,
            moneyFormatter: widget.moneyFormatter,
            onCategoryPressed: widget.onCategoryPressed,
          ),
        },
      ],
    );
  }

  Padding _buildMessage({required String message}) => Padding(
    padding: const .symmetric(vertical: 12.0, horizontal: 20.0),
    child: Text(
      message,
      style: context.typography.bodyMedium?.copyWith(
        color: context.colors.onSurfaceVariant,
      ),
    ),
  );
}
