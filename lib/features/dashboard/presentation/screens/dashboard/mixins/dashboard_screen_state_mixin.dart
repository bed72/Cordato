import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/dashboard/presentation/screens/dashboard/dashboard_screen.dart';

mixin DashboardScreenStateMixin on State<DashboardScreen> {
  int get recentExpensesLimit => 6;

  late DateTime metricsMonth;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    metricsMonth = DateTime(today.year, today.month);
    widget.userCommand.execute.run();
    loadExpenses();
    loadInsights();
    loadMetrics();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.userCommand != widget.userCommand) {
      widget.userCommand.execute.run();
    }

    if (oldWidget.expensesCommand != widget.expensesCommand) {
      oldWidget.expensesCommand.dispose();
      loadExpenses();
    }

    if (oldWidget.insightsCommand != widget.insightsCommand) {
      oldWidget.insightsCommand.dispose();
      loadInsights();
    }

    if (oldWidget.metricsCommand != widget.metricsCommand) {
      oldWidget.metricsCommand.dispose();
      loadMetrics();
    }
  }

  @override
  void dispose() {
    widget.expensesCommand.dispose();
    widget.insightsCommand.dispose();
    widget.metricsCommand.dispose();
    super.dispose();
  }

  void loadExpenses() => widget.expensesCommand.execute.run((
    pageLink: null,
    pageSize: recentExpensesLimit,
  ));

  void loadInsights() => widget.insightsCommand.execute.run();

  void loadMetrics() => widget.metricsCommand.execute.run((
    startDate: metricsMonth,
    endDate: DateTime(metricsMonth.year, metricsMonth.month + 1, 0),
    groupBy: .category,
  ));

  void previousMetricsMonth() => _changeMetricsMonth(-1);

  void nextMetricsMonth() => _changeMetricsMonth(1);

  void _changeMetricsMonth(int offset) {
    if (widget.metricsCommand.execute.isRunning.value) return;
    setState(() {
      metricsMonth = DateTime(metricsMonth.year, metricsMonth.month + offset);
    });
    loadMetrics();
  }

  Future<void> refreshMetrics() async {
    if (widget.metricsCommand.execute.isRunning.value) return;

    try {
      await widget.metricsCommand.execute.runAsync((
        startDate: metricsMonth,
        endDate: DateTime(metricsMonth.year, metricsMonth.month + 1, 0),
        groupBy: .category,
      ));
    } catch (_) {
      return;
    }
  }

  Future<void> refreshDashboard() async {
    await Future.wait([refreshExpenses(), refreshInsights(), refreshMetrics()]);
  }

  Future<void> refreshInsights() async {
    if (widget.insightsCommand.execute.isRunning.value) return;

    try {
      await widget.insightsCommand.execute.runAsync();
    } catch (_) {
      return;
    }
  }

  Future<void> refreshExpenses() async {
    if (widget.expensesCommand.execute.isRunning.value) return;

    try {
      await widget.expensesCommand.execute.runAsync((
        pageLink: null,
        pageSize: recentExpensesLimit,
      ));
    } catch (_) {
      return;
    }
  }

  Future<void> openExpense() async {
    await widget.onExpensePressed?.call();
    if (!mounted) return;
    loadExpenses();
    loadInsights();
    loadMetrics();
  }

  Future<void> openExpenses() async {
    await widget.onSeeAllExpensesPressed?.call();
    if (!mounted) return;
    loadExpenses();
    loadInsights();
    loadMetrics();
  }
}
