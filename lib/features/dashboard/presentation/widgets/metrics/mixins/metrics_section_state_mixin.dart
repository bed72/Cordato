import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cordato/features/dashboard/presentation/screens/dashboard/bloc/dashboard_bloc.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/bloc/dashboard_event.dart';
import 'package:cordato/features/dashboard/presentation/widgets/metrics/metrics_section_widget.dart';

mixin MetricsSectionStateMixin on State<MetricsSectionWidget> {
  int? _previousTotalCents;

  int? get displayedTotalCents =>
      widget.metrics?.totalAmount ?? _previousTotalCents;

  ({DateTime from, DateTime to})? get metricsPeriod {
    final month = context.read<DashboardBloc?>()?.state.selectedMonth;
    if (month == null) return null;

    return (
      from: DateTime(month.year, month.month),
      to: DateTime(month.year, month.month + 1, 0),
    );
  }

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

    _previousTotalCents = metrics.totalAmount;
  }

  VoidCallback? expensesChangedCallback() {
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
}
