import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/dashboard/presentation/screens/dashboard/dashboard_screen.dart';

mixin DashboardScreenStateMixin on State<DashboardScreen> {
  int get recentExpensesLimit => 6;

  late DateTime selectedMonth;
  int _dependenciesVersion = 0;
  bool _userRefreshPending = false;
  bool _refreshPendingAfterNavigation = false;

  DateTime get monthEnd =>
      DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

  bool get isLoading =>
      widget.firstExpenseMonthCommand.execute.isRunning.value ||
      widget.expensesCommand.execute.isRunning.value ||
      widget.insightsCommand.execute.isRunning.value ||
      widget.metricsCommand.execute.isRunning.value;

  bool get canGoToPreviousMonth {
    final result = widget.firstExpenseMonthCommand.execute.value;
    if (result == null || result.isLeft || result.right == null) return false;
    return selectedMonth.isAfter(result.right!);
  }

  bool get canGoToNextMonth {
    final today = DateTime.now();
    return selectedMonth.isBefore(DateTime(today.year, today.month));
  }

  @override
  void initState() {
    super.initState();

    final today = DateTime.now();
    selectedMonth = DateTime(today.year, today.month);
    widget.expensesCommand.execute.isRunning.addListener(_loadingChanged);
    widget.insightsCommand.execute.isRunning.addListener(_loadingChanged);
    widget.metricsCommand.execute.isRunning.addListener(_loadingChanged);
    widget.firstExpenseMonthCommand.execute.isRunning.addListener(
      _loadingChanged,
    );
    widget.firstExpenseMonthCommand.execute.run();
    widget.userCommand.execute.run();
    widget.userCommand.execute.isRunning.addListener(_userLoadingChanged);
    loadExpenses();
    loadInsights();
    loadMetrics();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.expensesCommand != widget.expensesCommand ||
        oldWidget.insightsCommand != widget.insightsCommand ||
        oldWidget.metricsCommand != widget.metricsCommand ||
        oldWidget.firstExpenseMonthCommand != widget.firstExpenseMonthCommand) {
      _dependenciesVersion++;
      _refreshPendingAfterNavigation = false;
    }

    if (oldWidget.userCommand != widget.userCommand) {
      _userRefreshPending = false;
      oldWidget.userCommand.execute.isRunning.removeListener(
        _userLoadingChanged,
      );
      oldWidget.userCommand.dispose();
      widget.userCommand.execute.isRunning.addListener(_userLoadingChanged);
      widget.userCommand.execute.run();
    }

    if (oldWidget.firstExpenseMonthCommand != widget.firstExpenseMonthCommand) {
      oldWidget.firstExpenseMonthCommand.execute.isRunning.removeListener(
        _loadingChanged,
      );
      oldWidget.firstExpenseMonthCommand.dispose();
      widget.firstExpenseMonthCommand.execute.isRunning.addListener(
        _loadingChanged,
      );
      widget.firstExpenseMonthCommand.execute.run();
    }

    if (oldWidget.expensesCommand != widget.expensesCommand) {
      oldWidget.expensesCommand.execute.isRunning.removeListener(
        _loadingChanged,
      );
      oldWidget.expensesCommand.dispose();
      widget.expensesCommand.execute.isRunning.addListener(_loadingChanged);
      loadExpenses();
    }

    if (oldWidget.insightsCommand != widget.insightsCommand) {
      oldWidget.insightsCommand.execute.isRunning.removeListener(
        _loadingChanged,
      );
      oldWidget.insightsCommand.dispose();
      widget.insightsCommand.execute.isRunning.addListener(_loadingChanged);
      loadInsights();
    }

    if (oldWidget.metricsCommand != widget.metricsCommand) {
      oldWidget.metricsCommand.execute.isRunning.removeListener(
        _loadingChanged,
      );
      oldWidget.metricsCommand.dispose();
      widget.metricsCommand.execute.isRunning.addListener(_loadingChanged);
      loadMetrics();
    }
  }

  @override
  void dispose() {
    widget.expensesCommand.execute.isRunning.removeListener(_loadingChanged);
    widget.insightsCommand.execute.isRunning.removeListener(_loadingChanged);
    widget.metricsCommand.execute.isRunning.removeListener(_loadingChanged);
    widget.firstExpenseMonthCommand.execute.isRunning.removeListener(
      _loadingChanged,
    );
    widget.firstExpenseMonthCommand.dispose();
    widget.expensesCommand.dispose();
    widget.insightsCommand.dispose();
    widget.metricsCommand.dispose();
    widget.userCommand.execute.isRunning.removeListener(_userLoadingChanged);
    widget.userCommand.dispose();
    super.dispose();
  }

  void _loadingChanged() {
    if (!mounted) return;
    setState(() {});
    if (_refreshPendingAfterNavigation && !isLoading) {
      _refreshPendingAfterNavigation = false;
      final version = _dependenciesVersion;
      Future<void>.microtask(() async {
        if (!mounted || version != _dependenciesVersion) return;
        await _refreshAfterNavigation();
      });
    }
  }

  void loadExpenses() => widget.expensesCommand.execute.run((
    to: monthEnd,
    pageLink: null,
    from: selectedMonth,
    pageSize: recentExpensesLimit,
  ));

  void loadInsights() => widget.insightsCommand.execute.run((
    year: selectedMonth.year,
    month: selectedMonth.month,
  ));

  void loadMetrics() => widget.metricsCommand.execute.run((
    endDate: monthEnd,
    groupBy: .category,
    startDate: selectedMonth,
  ));

  void previousMonth() => _changeMonth(-1);

  void nextMonth() => _changeMonth(1);

  void _changeMonth(int offset) {
    if (isLoading ||
        (offset > 0 && !canGoToNextMonth) ||
        (offset < 0 && !canGoToPreviousMonth)) {
      return;
    }
    setState(() {
      selectedMonth = DateTime(
        selectedMonth.year,
        selectedMonth.month + offset,
      );
    });
    loadExpenses();
    loadInsights();
    loadMetrics();
  }

  Future<void> refreshMetrics() async {
    if (widget.metricsCommand.execute.isRunning.value) return;

    try {
      await widget.metricsCommand.execute.runAsync((
        startDate: selectedMonth,
        endDate: monthEnd,
        groupBy: .category,
      ));
    } catch (_) {
      return;
    }
  }

  Future<void> refreshDashboard() async {
    if (isLoading) return;
    final version = _dependenciesVersion;
    try {
      final data = await widget.firstExpenseMonthCommand.execute.runAsync();

      if (!mounted || version != _dependenciesVersion) return;
      if (data != null && data.isRight) {
        final today = DateTime.now();
        final currentMonth = DateTime(today.year, today.month);
        final firstMonth = data.right ?? currentMonth;
        if (selectedMonth.isBefore(firstMonth)) {
          setState(() {
            selectedMonth = firstMonth.isAfter(currentMonth)
                ? currentMonth
                : firstMonth;
          });
        }
      }
    } catch (_) {
      if (!mounted || version != _dependenciesVersion) return;
    }
    await Future.wait([refreshExpenses(), refreshInsights(), refreshMetrics()]);
  }

  Future<void> refreshInsights() async {
    if (widget.insightsCommand.execute.isRunning.value) return;

    try {
      await widget.insightsCommand.execute.runAsync((
        year: selectedMonth.year,
        month: selectedMonth.month,
      ));
    } catch (_) {
      return;
    }
  }

  Future<void> refreshExpenses() async {
    if (widget.expensesCommand.execute.isRunning.value) return;

    try {
      await widget.expensesCommand.execute.runAsync((
        to: monthEnd,
        pageLink: null,
        from: selectedMonth,
        pageSize: recentExpensesLimit,
      ));
    } catch (_) {
      return;
    }
  }

  Future<void> openExpense() async {
    final version = _dependenciesVersion;
    await widget.onExpensePressed?.call();
    if (!mounted || version != _dependenciesVersion) return;
    await _refreshAfterNavigation();
  }

  Future<void> openUser() => _openUserNavigation(widget.onAvatarPressed);

  Future<void> openSettings() => _openUserNavigation(widget.onMenuPressed);

  Future<void> _openUserNavigation(Future<void> Function()? navigate) async {
    if (navigate == null) return;
    final command = widget.userCommand;
    await navigate();
    if (!mounted || command != widget.userCommand) return;
    if (command.execute.isRunning.value) {
      _userRefreshPending = true;
      return;
    }
    command.execute.run();
  }

  void _userLoadingChanged() {
    if (!mounted ||
        !_userRefreshPending ||
        widget.userCommand.execute.isRunning.value) {
      return;
    }
    _userRefreshPending = false;
    final command = widget.userCommand;
    Future<void>.microtask(() {
      if (!mounted || command != widget.userCommand) return;
      command.execute.run();
    });
  }

  Future<void> openExpenses() async {
    final version = _dependenciesVersion;
    await widget.onSeeAllExpensesPressed?.call(selectedMonth);
    if (!mounted || version != _dependenciesVersion) return;
    await _refreshAfterNavigation();
  }

  Future<void> _refreshAfterNavigation() async {
    if (isLoading) {
      _refreshPendingAfterNavigation = true;
      return;
    }
    await refreshDashboard();
  }
}
