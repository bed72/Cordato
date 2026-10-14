import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';

import 'package:cordato/features/expense/presentation/screens/expenses/expenses_screen.dart';
import 'package:cordato/features/expense/presentation/extensions/expense_category_extension.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/commands/get_expenses_command.dart';

import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/confirmation_bottom_sheet_widget.dart';

mixin ExpensesScreenStateMixin on State<ExpensesScreen> {
  String? activeCategory;
  ({DateTime from, DateTime to})? activePeriod;
  String? nextPageLink;
  String? pendingDeleteId;
  String? deletingExpenseId;

  int _queryRevision = 0;
  bool hasLoaded = false;
  bool hasFailure = false;
  bool _retryRefresh = true;
  bool isEditingExpense = false;
  int? _pendingRefreshRevision;

  final List<ExpenseEntity> expenses = [];
  final scrollController = ScrollController();

  int get pageSize => 20;

  bool get isLoading =>
      widget.getCommand.execute.isRunning.value ||
      _pendingRefreshRevision == _queryRevision;

  bool get canRemoveFilters =>
      mounted &&
      !isLoading &&
      !isEditingExpense &&
      pendingDeleteId == null &&
      deletingExpenseId == null &&
      !widget.deleteCommand.execute.isRunning.value;

  String? get periodLabel {
    final period = activePeriod;
    if (period == null) return null;

    final lastDay = DateTime(period.from.year, period.from.month + 1, 0);
    if (period.from.day != 1 || _civilDay(period.to) != _civilDay(lastDay)) {
      return widget.dateFormatter.formatShortPeriod(period.from, period.to);
    }

    return '${widget.dateFormatter.formatMonth(period.from)} de ${period.from.year}';
  }

  String? get categoryLabel {
    final category = activeCategory;
    return category == null
        ? null
        : ExpenseCategoryEnum.values
                  .where((value) => value.value == category)
                  .firstOrNull
                  ?.label ??
              category;
  }

  String? get filterLabel {
    final labels = [categoryLabel, periodLabel].whereType<String>().toList();

    return labels.isEmpty ? null : labels.join(' · ');
  }

  @override
  void initState() {
    super.initState();
    activeCategory = widget.category;
    activePeriod = widget.period;
    scrollController.addListener(loadNearEnd);
    widget.getCommand.execute.isRunning.addListener(_schedulePendingRefresh);
    _restartQuery();
  }

  @override
  void didUpdateWidget(covariant ExpensesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.deleteCommand != widget.deleteCommand) {
      oldWidget.deleteCommand.dispose();
      pendingDeleteId = null;
      deletingExpenseId = null;
    }

    final commandChanged = oldWidget.getCommand != widget.getCommand;
    final filtersChanged =
        oldWidget.category != widget.category ||
        oldWidget.period != widget.period;

    if (commandChanged) {
      oldWidget.getCommand.execute.isRunning.removeListener(
        _schedulePendingRefresh,
      );
      oldWidget.getCommand.dispose();
      widget.getCommand.execute.isRunning.addListener(_schedulePendingRefresh);
    }

    if (filtersChanged) {
      activeCategory = widget.category;
      activePeriod = widget.period;
    }

    if (commandChanged || filtersChanged) {
      isEditingExpense = false;
      pendingDeleteId = null;
      deletingExpenseId = null;
      _restartQuery();
    }
  }

  @override
  void dispose() {
    _queryRevision++;
    _pendingRefreshRevision = null;
    widget.getCommand.execute.isRunning.removeListener(_schedulePendingRefresh);
    scrollController.removeListener(loadNearEnd);
    scrollController.dispose();
    widget.getCommand.dispose();
    widget.deleteCommand.dispose();
    super.dispose();
  }

  void loadNearEnd() {
    if (!mounted || !scrollController.hasClients || hasFailure || !hasLoaded) {
      return;
    }
    if (scrollController.position.extentAfter < 240.0) loadNextPage();
  }

  Future<void> refreshExpenses() => _loadPage(refresh: true);

  Future<void> removeCategoryFilter() async {
    if (!canRemoveFilters || activeCategory == null) return;

    setState(() => activeCategory = null);
    await _restartQuery();
  }

  Future<void> removePeriodFilter() async {
    if (!canRemoveFilters || activePeriod == null) return;

    setState(() => activePeriod = null);
    await _restartQuery();
  }

  Future<void> _restartQuery() async {
    if (!mounted) return;

    final command = widget.getCommand;
    setState(() {
      _queryRevision++;
      expenses.clear();
      nextPageLink = null;
      hasLoaded = false;
      hasFailure = false;
      _retryRefresh = true;
      _pendingRefreshRevision = command.execute.isRunning.value
          ? _queryRevision
          : null;
    });

    final revision = _queryRevision;
    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isCurrentQuery(command, revision) && scrollController.hasClients) {
          scrollController.jumpTo(0);
        }
      });
    }

    if (_pendingRefreshRevision == null) await refreshExpenses();
  }

  void _schedulePendingRefresh() {
    final command = widget.getCommand;
    final revision = _pendingRefreshRevision;
    if (revision == null || command.execute.isRunning.value) return;

    Future<void>.microtask(() {
      if (!_isCurrentQuery(command, revision) ||
          _pendingRefreshRevision != revision ||
          command.execute.isRunning.value) {
        return;
      }

      _pendingRefreshRevision = null;
      refreshExpenses();
    });
  }

  Future<void> loadNextPage() async {
    if (nextPageLink == null) return;
    await _loadPage(refresh: false);
  }

  void retry() {
    _retryRefresh ? refreshExpenses() : loadNextPage();
  }

  Future<void> editExpense(String id) async {
    final navigate = widget.onExpensePressed;

    if (navigate == null ||
        isLoading ||
        pendingDeleteId != null ||
        isEditingExpense) {
      return;
    }

    final command = widget.getCommand;
    final revision = _queryRevision;
    setState(() => isEditingExpense = true);

    try {
      final updated = await navigate(id);
      if (!_isCurrentQuery(command, revision) || updated == null) return;
      widget.onExpensesChanged?.call();

      final index = expenses.indexWhere((expense) => expense.id == id);
      if (index < 0) return;

      setState(() => _applyUpdatedExpense(index, updated));
    } finally {
      if (_isCurrentQuery(command, revision)) {
        setState(() => isEditingExpense = false);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isCurrentQuery(command, revision)) loadNearEnd();
    });
  }

  Future<bool> confirmDeleteExpense(String id) async {
    if (isLoading ||
        isEditingExpense ||
        pendingDeleteId != null ||
        widget.deleteCommand.execute.isRunning.value) {
      return false;
    }

    final command = widget.deleteCommand;
    final queryCommand = widget.getCommand;
    final revision = _queryRevision;
    bool deleted = false;
    bool confirmed = false;

    setState(() => pendingDeleteId = id);

    try {
      await showConfirmationBottomSheetWidget(
        context: context,
        confirmLabel: 'Excluir',
        onConfirm: () => confirmed = true,
        title: 'Deseja excluir esta despesa?',
        subtitle: 'Esta ação não pode ser desfeita.',
      );

      if (!_isCurrentQuery(queryCommand, revision) ||
          widget.deleteCommand != command ||
          !confirmed) {
        return false;
      }

      setState(() => deletingExpenseId = id);
      final data = await command.execute.runAsync(id);
      if (!mounted ||
          !_isCurrentQuery(queryCommand, revision) ||
          widget.deleteCommand != command) {
        return false;
      }

      final snapshot = command.execute.results.value;
      if (!snapshot.isRunning &&
          !snapshot.hasError &&
          snapshot.paramData == id &&
          snapshot.data == true &&
          data == true) {
        widget.onExpensesChanged?.call();
        deleted = true;
        context.showToast(
          variant: .success,
          title: 'Despesa excluída',
          description: 'A despesa foi removida com sucesso.',
        );
        return true;
      }

      showDeleteFailure();
      return false;
    } on CommandFailureException catch (failure) {
      if (_isCurrentQuery(queryCommand, revision) &&
          widget.deleteCommand == command) {
        final value = failure.errors;
        context.showToast(
          variant: .error,
          title: value.errors.firstOrNull?.title ?? 'Erro ao excluir despesa',
          description: value.errors.isEmpty
              ? 'Não foi possível excluir a despesa. Tente novamente.'
              : value.errors
                    .map(
                      (error) => error.detail ?? error.title ?? 'Não foi possível excluir a despesa. Tente novamente.',
                    )
                    .join('\n'),
        );
      }
      return false;
    } catch (_) {
      if (_isCurrentQuery(queryCommand, revision) &&
          widget.deleteCommand == command) {
        showDeleteFailure();
      }

      return false;
    } finally {
      if (_isCurrentQuery(queryCommand, revision) &&
          widget.deleteCommand == command) {
        setState(() {
          deletingExpenseId = null;
          if (!deleted) pendingDeleteId = null;
        });
      }
    }
  }

  void showDeleteFailure() => context.showToast(
    variant: .error,
    title: 'Erro ao excluir despesa',
    description: 'Não foi possível excluir a despesa. Tente novamente.',
  );

  Future<void> deleteExpenseAccessibly(String id) async {
    if (await confirmDeleteExpense(id) && mounted) removeDeletedExpense(id);
  }

  DateTime _civilDay(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  bool _isWithinPeriod(DateTime date) {
    final period = activePeriod;
    if (period == null) return true;

    final day = _civilDay(date);
    return !day.isBefore(_civilDay(period.from)) &&
        !day.isAfter(_civilDay(period.to));
  }

  void _applyUpdatedExpense(int index, ExpenseEntity updated) {
    if (!_isWithinPeriod(updated.occurredOn) ||
        (activeCategory != null && updated.category.value != activeCategory)) {
      expenses.removeAt(index);
      return;
    }

    if (_civilDay(expenses[index].occurredOn) ==
        _civilDay(updated.occurredOn)) {
      expenses[index] = updated;
      return;
    }

    expenses.removeAt(index);
    _insertExpense(updated);
  }

  void _insertExpense(ExpenseEntity expense) {
    final day = _civilDay(expense.occurredOn);

    if (expenses.isEmpty || !day.isAfter(_civilDay(expenses.last.occurredOn))) {
      expenses.add(expense);
      return;
    }

    int start = 0;
    int end = expenses.length;

    while (start < end) {
      final middle = (start + end) ~/ 2;

      day.isAfter(_civilDay(expenses[middle].occurredOn))
          ? end = middle
          : start = middle + 1;
    }

    expenses.insert(start, expense);
  }

  void removeDeletedExpense(String id) {
    if (!mounted || pendingDeleteId != id) return;

    final command = widget.getCommand;
    final revision = _queryRevision;
    setState(() {
      expenses.removeWhere((expense) => expense.id == id);
      pendingDeleteId = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isCurrentQuery(command, revision)) loadNearEnd();
    });
  }

  Future<void> _loadPage({required bool refresh}) async {
    if (!mounted || isLoading || isEditingExpense || pendingDeleteId != null) {
      return;
    }
    final command = widget.getCommand;
    final revision = _queryRevision;

    setState(() {
      hasFailure = false;
      _retryRefresh = refresh;
    });

    try {
      final parameters = (
        pageSize: pageSize,
        to: activePeriod?.to,
        category: activeCategory,
        from: activePeriod?.from,
        pageLink: refresh ? null : nextPageLink,
      );
      final previous = command.execute.results.value;
      final execution = command.execute.runAsync(parameters);
      final started = command.execute.results.value;
      final didStart =
          !identical(previous, started) &&
          started.isRunning &&
          started.paramData == parameters;
      final data = await execution;

      if (!_isCurrentQuery(command, revision)) return;
      final snapshot = command.execute.results.value;

      setState(() {
        if (didStart &&
            !identical(started, snapshot) &&
            !snapshot.isRunning &&
            !snapshot.hasError &&
            snapshot.paramData == parameters &&
            data != null &&
            identical(snapshot.data, data)) {
          if (refresh) expenses.clear();
          for (final expense in data.items) {
            _insertExpense(expense);
          }
          nextPageLink = data.next;
          hasLoaded = true;
          return;
        }

        hasFailure = true;
      });
    } catch (_) {
      if (!_isCurrentQuery(command, revision)) return;
      setState(() => hasFailure = true);
    }

    if (!_isCurrentQuery(command, revision) || hasFailure) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isCurrentQuery(command, revision)) loadNearEnd();
    });
  }

  bool _isCurrentQuery(GetExpensesCommand command, int revision) =>
      mounted && widget.getCommand == command && _queryRevision == revision;
}
