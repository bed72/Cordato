import 'package:material_ui/material_ui.dart';
import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/dashboard_screen.dart';

mixin DashboardScreenStateMixin on State<DashboardScreen> {
  int get recentExpensesLimit => 6;

  late DateTime selectedMonth;
  bool isRecovering = false;
  int _dependenciesVersion = 0;
  bool hasFinancialError = false;
  bool _isOpeningExpenses = false;
  bool _userRefreshPending = false;
  bool _isRefreshingDashboard = false;
  bool _refreshPendingAfterNavigation = false;

  DateTime get monthEnd =>
      DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

  bool get isLoading =>
      _isRefreshingDashboard ||
      widget.firstExpenseMonthCommand.execute.isRunning.value ||
      widget.expensesCommand.execute.isRunning.value ||
      widget.insightsCommand.execute.isRunning.value ||
      widget.metricsCommand.execute.isRunning.value;

  bool get canRetryDashboard =>
      hasFinancialError &&
      !isLoading &&
      !widget.userCommand.execute.isRunning.value;

  bool get canGoToPreviousMonth {
    if (widget.firstExpenseMonthCommand.execute.results.value.hasError ||
        widget.firstExpenseMonthCommand.execute.errors.value != null) {
      return false;
    }

    final data = widget.firstExpenseMonthCommand.execute.value;
    if (data == null || data.isLeft || data.right == null) return false;

    return selectedMonth.isAfter(data.right!);
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
    _observeFinancialResults(widget);
    widget.expensesCommand.execute.isRunning.addListener(_loadingChanged);
    widget.insightsCommand.execute.isRunning.addListener(_loadingChanged);
    widget.metricsCommand.execute.isRunning.addListener(_loadingChanged);
    widget.firstExpenseMonthCommand.execute.isRunning.addListener(
      _loadingChanged,
    );
    widget.firstExpenseMonthCommand.execute.run();
    widget.userCommand.execute.isRunning.addListener(_userLoadingChanged);
    widget.userCommand.execute.run();
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
        oldWidget.firstExpenseMonthCommand != widget.firstExpenseMonthCommand ||
        oldWidget.userCommand != widget.userCommand) {
      _dependenciesVersion++;
      _refreshPendingAfterNavigation = false;
      _isRefreshingDashboard = false;
      isRecovering = false;
      _removeFinancialObservers(oldWidget);
      _observeFinancialResults(widget);
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
    _dependenciesVersion++;
    _removeFinancialObservers(widget);
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
    if (_hasFinancialFailure) hasFinancialError = true;

    setState(() {});

    if (_refreshPendingAfterNavigation &&
        !isLoading &&
        !widget.userCommand.execute.isRunning.value) {
      _refreshPendingAfterNavigation = false;

      final version = _dependenciesVersion;
      Future<void>.microtask(() async {
        if (!mounted || version != _dependenciesVersion) return;
        await _refreshAfterNavigation();
      });
    }
  }

  List<Listenable> _financialSignals(DashboardScreen screen) => [
    screen.expensesCommand.execute.results,
    screen.expensesCommand.execute.errors,
    screen.insightsCommand.execute.results,
    screen.insightsCommand.execute.errors,
    screen.metricsCommand.execute.results,
    screen.metricsCommand.execute.errors,
  ];

  void _observeFinancialResults(DashboardScreen screen) {
    for (final signal in _financialSignals(screen)) {
      signal.addListener(_loadingChanged);
    }
  }

  void _removeFinancialObservers(DashboardScreen screen) {
    for (final signal in _financialSignals(screen)) {
      signal.removeListener(_loadingChanged);
    }
  }

  bool get _hasFinancialFailure =>
      _failed(widget.expensesCommand.execute) ||
      _failed(widget.insightsCommand.execute) ||
      _failed(widget.metricsCommand.execute);

  bool _failed<TParam, TResult>(
    Command<TParam, Either<ErrorsEntity, TResult>?> command,
  ) {
    final data = command.results.value;

    return !data.isRunning &&
        (data.hasError ||
            command.errors.value != null ||
            data.data?.isLeft == true);
  }

  void loadExpenses() => widget.expensesCommand.execute.run((
    to: monthEnd,
    category: null,
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

  Future<bool> refreshMetrics() async {
    if (widget.metricsCommand.execute.isRunning.value) return false;

    try {
      final data = await widget.metricsCommand.execute.runAsync((
        endDate: monthEnd,
        groupBy: .category,
        startDate: selectedMonth,
      ));

      return data?.isRight == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> refreshDashboard() async {
    if (isLoading || widget.userCommand.execute.isRunning.value) return;

    final version = _dependenciesVersion;
    final recovering = hasFinancialError;
    setState(() {
      _isRefreshingDashboard = true;
      isRecovering = recovering;
    });

    final userRefresh = recovering ? _refreshUser() : Future<void>.value();
    try {
      await _refreshFirstMonth(version);

      if (!mounted || version != _dependenciesVersion) return;
      final results = await Future.wait([
        refreshExpenses(),
        refreshInsights(),
        refreshMetrics(),
      ]);
      await userRefresh;

      if (!mounted || version != _dependenciesVersion) return;
      if (recovering && results.every((success) => success)) {
        hasFinancialError = false;
      }
    } finally {
      if (mounted && version == _dependenciesVersion) {
        setState(() {
          isRecovering = false;
          _isRefreshingDashboard = false;
        });

        _loadingChanged();
      }
    }
  }

  Future<void> retryDashboard() async {
    if (!canRetryDashboard) return;
    await refreshDashboard();
  }

  Future<void> _refreshUser() async {
    try {
      await widget.userCommand.execute.runAsync();
    } catch (_) {
      return;
    }
  }

  Future<void> _refreshFirstMonth(int version) async {
    try {
      final data = await widget.firstExpenseMonthCommand.execute.runAsync();

      if (!mounted || version != _dependenciesVersion) return;
      if (data == null || data.isLeft) return;
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
    } catch (_) {
      return;
    }
  }

  Future<bool> refreshInsights() async {
    if (widget.insightsCommand.execute.isRunning.value) return false;

    try {
      final data = await widget.insightsCommand.execute.runAsync((
        year: selectedMonth.year,
        month: selectedMonth.month,
      ));

      return data?.isRight == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> refreshExpenses() async {
    if (widget.expensesCommand.execute.isRunning.value) return false;

    try {
      final data = await widget.expensesCommand.execute.runAsync((
        to: monthEnd,
        category: null,
        pageLink: null,
        from: selectedMonth,
        pageSize: recentExpensesLimit,
      ));

      return data?.isRight == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> openExpense() async {
    final version = _dependenciesVersion;
    final changed = await widget.onExpensePressed?.call();
    if (!mounted || version != _dependenciesVersion || changed != true) return;

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
    _loadingChanged();

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

  Future<void> openExpenses({String? category}) async {
    if (_isOpeningExpenses) return;
    final version = _dependenciesVersion;
    _isOpeningExpenses = true;

    try {
      final changed = await widget.onSeeAllExpensesPressed?.call(
        selectedMonth,
        category: category,
      );

      if (!mounted || version != _dependenciesVersion || changed != true) {
        return;
      }

      await _refreshAfterNavigation();
    } finally {
      _isOpeningExpenses = false;
    }
  }

  Future<void> _refreshAfterNavigation() async {
    if (isLoading || widget.userCommand.execute.isRunning.value) {
      _refreshPendingAfterNavigation = true;
      return;
    }

    await refreshDashboard();
  }
}
