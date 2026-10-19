import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cordato/features/dashboard/presentation/screens/dashboard/bloc/dashboard_bloc.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/bloc/dashboard_event.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/dashboard/presentation/widgets/metrics/animated_expense_total_widget.dart';

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

final class _MetricsSectionWidgetState extends State<MetricsSectionWidget> {
  int? _previousTotalCents;
  int? _initialTotalCents;
  ({DateTime from, DateTime to})? _previousPeriod;

  @override
  void initState() {
    super.initState();
    _rememberTotal();
  }

  @override
  void didUpdateWidget(covariant MetricsSectionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.metrics, widget.metrics)) return;
    _rememberTotal();
  }

  void _rememberTotal() {
    final metrics = widget.metrics;
    if (metrics == null) return;
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
    final metrics = widget.metrics;
    return metrics == null
        ? _buildSection(child: const ExpenseMetricsSkeletonWidget())
        : Padding(
            padding: const .only(top: 8.0, bottom: 20.0),
            child: _buildMetrics(metrics: metrics),
          );
  }

  Padding _buildSection({required Widget child}) =>
      Padding(padding: const .fromLTRB(20.0, 8.0, 20.0, 20.0), child: child);

  Column _buildMetrics({required ExpenseMetricsEntity metrics}) {
    final pages = metrics.categories?.cardPages ?? [];
    final month = context.read<DashboardBloc?>()?.state.selectedMonth;

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
            period: month == null
                ? null
                : (
                    from: DateTime(month.year, month.month),
                    to: DateTime(month.year, month.month + 1, 0),
                  ),
            onExpensesChanged: _expensesChangedCallback(),
          ),
        },
      ],
    );
  }

  VoidCallback? _expensesChangedCallback() {
    final captured = context.read<DashboardBloc?>();
    if (captured == null) return null;
    return () {
      if (mounted &&
          !captured.isClosed &&
          identical(context.read<DashboardBloc?>(), captured)) {
        captured.add(DashboardExpensesChanged());
      }
    };
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
