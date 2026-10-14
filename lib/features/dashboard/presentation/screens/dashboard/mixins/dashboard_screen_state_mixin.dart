import 'package:command_it/command_it.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/dashboard/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:cordato/features/metrics/domain/enums/expense_metrics_group_by_enum.dart';

mixin DashboardScreenStateMixin on State<DashboardScreen> {
  int get recentExpensesLimit => 6;

  late DateTime selectedMonth;
  late Listenable monthControlsListenable;
  late Listenable retryControlsListenable;

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
    final data = widget.firstExpenseMonthCommand.execute.results.value;
    if (data.isRunning || data.hasError || data.data == null) {
      return false;
    }

    return selectedMonth.isAfter(data.data!);
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
    _updateControlListenables();
    _observeFinancialResults(widget);
    widget.expensesCommand.execute.isRunning.addListener(_executionChanged);
    widget.insightsCommand.execute.isRunning.addListener(_executionChanged);
    widget.metricsCommand.execute.isRunning.addListener(_executionChanged);
    widget.firstExpenseMonthCommand.execute.isRunning.addListener(
      _executionChanged,
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
      _userRefreshPending = false;
      _isOpeningExpenses = false;
      _refreshPendingAfterNavigation = false;
      _isRefreshingDashboard = false;
      isRecovering = false;
      _updateControlListenables();
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
        _executionChanged,
      );
      oldWidget.firstExpenseMonthCommand.dispose();
      widget.firstExpenseMonthCommand.execute.isRunning.addListener(
        _executionChanged,
      );
      widget.firstExpenseMonthCommand.execute.run();
    }

    if (oldWidget.expensesCommand != widget.expensesCommand) {
      oldWidget.expensesCommand.execute.isRunning.removeListener(
        _executionChanged,
      );
      oldWidget.expensesCommand.dispose();
      widget.expensesCommand.execute.isRunning.addListener(_executionChanged);
      loadExpenses();
    }

    if (oldWidget.insightsCommand != widget.insightsCommand) {
      oldWidget.insightsCommand.execute.isRunning.removeListener(
        _executionChanged,
      );
      oldWidget.insightsCommand.dispose();
      widget.insightsCommand.execute.isRunning.addListener(_executionChanged);
      loadInsights();
    }

    if (oldWidget.metricsCommand != widget.metricsCommand) {
      oldWidget.metricsCommand.execute.isRunning.removeListener(
        _executionChanged,
      );
      oldWidget.metricsCommand.dispose();
      widget.metricsCommand.execute.isRunning.addListener(_executionChanged);
      loadMetrics();
    }
  }

  @override
  void dispose() {
    _dependenciesVersion++;
    _userRefreshPending = false;
    _refreshPendingAfterNavigation = false;
    _removeFinancialObservers(widget);
    widget.expensesCommand.execute.isRunning.removeListener(_executionChanged);
    widget.insightsCommand.execute.isRunning.removeListener(_executionChanged);
    widget.metricsCommand.execute.isRunning.removeListener(_executionChanged);
    widget.firstExpenseMonthCommand.execute.isRunning.removeListener(
      _executionChanged,
    );
    widget.firstExpenseMonthCommand.dispose();
    widget.expensesCommand.dispose();
    widget.insightsCommand.dispose();
    widget.metricsCommand.dispose();
    widget.userCommand.execute.isRunning.removeListener(_userLoadingChanged);
    widget.userCommand.dispose();
    super.dispose();
  }

  void _updateControlListenables() {
    final executionSignals = [
      widget.expensesCommand.execute.isRunning,
      widget.insightsCommand.execute.isRunning,
      widget.metricsCommand.execute.isRunning,
      widget.firstExpenseMonthCommand.execute.isRunning,
    ];
    monthControlsListenable = Listenable.merge([
      ...executionSignals,
      widget.firstExpenseMonthCommand.execute.results,
    ]);
    retryControlsListenable = Listenable.merge([
      ...executionSignals,
      widget.userCommand.execute.isRunning,
    ]);
  }

  void _financialResultChanged() {
    if (!mounted || hasFinancialError || !_hasFinancialFailure) return;

    setState(() => hasFinancialError = true);
  }

  void _executionChanged() {
    if (!mounted) return;

    if (_refreshPendingAfterNavigation &&
        !isLoading &&
        !widget.userCommand.execute.isRunning.value) {
      final version = _dependenciesVersion;
      Future<void>.microtask(() async {
        if (!mounted ||
            version != _dependenciesVersion ||
            !_refreshPendingAfterNavigation ||
            isLoading ||
            widget.userCommand.execute.isRunning.value) {
          return;
        }
        _refreshPendingAfterNavigation = false;
        await refreshDashboard();
      });
    }
  }

  List<Listenable> _financialSignals(DashboardScreen screen) => [
    screen.expensesCommand.execute.results,
    screen.insightsCommand.execute.results,
    screen.metricsCommand.execute.results,
  ];

  void _observeFinancialResults(DashboardScreen screen) {
    for (final signal in _financialSignals(screen)) {
      signal.addListener(_financialResultChanged);
    }
  }

  void _removeFinancialObservers(DashboardScreen screen) {
    for (final signal in _financialSignals(screen)) {
      signal.removeListener(_financialResultChanged);
    }
  }

  bool get _hasFinancialFailure =>
      _failed(widget.expensesCommand.execute) ||
      _failed(widget.insightsCommand.execute) ||
      _failed(widget.metricsCommand.execute);

  bool _failed<TParam, TResult>(Command<TParam, TResult> command) {
    final data = command.results.value;

    return !data.isRunning && data.hasError;
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
    final command = widget.metricsCommand;
    final version = _dependenciesVersion;
    if (command.execute.isRunning.value) return false;

    try {
      final input = (
        endDate: monthEnd,
        groupBy: ExpenseMetricsGroupByEnum.category,
        startDate: selectedMonth,
      );
      final previous = command.execute.results.value;
      final execution = command.execute.runAsync(input);
      final started = command.execute.results.value;
      final didStart =
          !identical(previous, started) &&
          started.isRunning &&
          started.paramData == input;
      final data = await execution;

      if (!mounted ||
          version != _dependenciesVersion ||
          command != widget.metricsCommand ||
          !didStart) {
        return false;
      }
      final terminal = command.execute.results.value;
      return !identical(started, terminal) &&
          !terminal.hasError &&
          !terminal.isRunning &&
          terminal.paramData == input &&
          terminal.data != null &&
          identical(terminal.data, data);
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

        _executionChanged();
      }
    }
  }

  Future<void> retryDashboard() async {
    if (!canRetryDashboard) return;
    await refreshDashboard();
  }

  Future<void> _refreshUser() async {
    final command = widget.userCommand;
    if (command.execute.isRunning.value) return;

    try {
      await command.execute.runAsync();
    } catch (_) {
      return;
    }
  }

  Future<void> _refreshFirstMonth(int version) async {
    final command = widget.firstExpenseMonthCommand;
    if (!mounted ||
        version != _dependenciesVersion ||
        command.execute.isRunning.value) {
      return;
    }
    try {
      final previous = command.execute.results.value;
      final execution = command.execute.runAsync();
      final started = command.execute.results.value;
      final didStart = !identical(previous, started) && started.isRunning;
      final data = await execution;

      if (!mounted || version != _dependenciesVersion) return;
      if (command != widget.firstExpenseMonthCommand || !didStart) return;
      final terminal = command.execute.results.value;
      if (identical(started, terminal) ||
          terminal.hasError ||
          terminal.isRunning ||
          terminal.data != data) {
        return;
      }
      final today = DateTime.now();
      final currentMonth = DateTime(today.year, today.month);
      final firstMonth = data ?? currentMonth;

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
    final command = widget.insightsCommand;
    final version = _dependenciesVersion;
    if (command.execute.isRunning.value) return false;

    try {
      final input = (year: selectedMonth.year, month: selectedMonth.month);
      final previous = command.execute.results.value;
      final execution = command.execute.runAsync(input);
      final started = command.execute.results.value;
      final didStart =
          !identical(previous, started) &&
          started.isRunning &&
          started.paramData == input;
      final data = await execution;

      if (!mounted ||
          version != _dependenciesVersion ||
          command != widget.insightsCommand ||
          !didStart) {
        return false;
      }
      final terminal = command.execute.results.value;
      return !identical(started, terminal) &&
          !terminal.hasError &&
          !terminal.isRunning &&
          terminal.paramData == input &&
          terminal.data != null &&
          identical(terminal.data, data);
    } catch (_) {
      return false;
    }
  }

  Future<bool> refreshExpenses() async {
    final command = widget.expensesCommand;
    final version = _dependenciesVersion;
    if (command.execute.isRunning.value) return false;

    try {
      final input = (
        to: monthEnd,
        category: null,
        pageLink: null,
        from: selectedMonth,
        pageSize: recentExpensesLimit,
      );
      final previous = command.execute.results.value;
      final execution = command.execute.runAsync(input);
      final started = command.execute.results.value;
      final didStart =
          !identical(previous, started) &&
          started.isRunning &&
          started.paramData == input;
      final data = await execution;

      if (!mounted ||
          version != _dependenciesVersion ||
          command != widget.expensesCommand ||
          !didStart) {
        return false;
      }
      final terminal = command.execute.results.value;
      return !identical(started, terminal) &&
          !terminal.hasError &&
          !terminal.isRunning &&
          terminal.paramData == input &&
          terminal.data != null &&
          identical(terminal.data, data);
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
    final version = _dependenciesVersion;
    final command = widget.userCommand;
    await navigate();
    if (!mounted ||
        version != _dependenciesVersion ||
        command != widget.userCommand) {
      return;
    }
    if (command.execute.isRunning.value) {
      _userRefreshPending = true;
      return;
    }

    _userRefreshPending = false;
    command.execute.run();
  }

  void _userLoadingChanged() {
    _executionChanged();

    if (!mounted ||
        !_userRefreshPending ||
        widget.userCommand.execute.isRunning.value) {
      return;
    }

    final command = widget.userCommand;
    final version = _dependenciesVersion;

    Future<void>.microtask(() {
      if (!mounted ||
          version != _dependenciesVersion ||
          command != widget.userCommand ||
          !_userRefreshPending ||
          command.execute.isRunning.value) {
        return;
      }
      _userRefreshPending = false;
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
      if (mounted && version == _dependenciesVersion) {
        _isOpeningExpenses = false;
      }
    }
  }

  Future<void> _refreshAfterNavigation() async {
    if (isLoading || widget.userCommand.execute.isRunning.value) {
      _refreshPendingAfterNavigation = true;
      return;
    }

    _refreshPendingAfterNavigation = false;
    await refreshDashboard();
  }
}
