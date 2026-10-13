import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/expenses_screen.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/confirmation_bottom_sheet_widget.dart';

mixin ExpensesScreenStateMixin on State<ExpensesScreen> {
  String? nextPageLink;
  String? pendingDeleteId;
  String? deletingExpenseId;

  bool isLoading = false;
  bool hasLoaded = false;
  bool hasFailure = false;
  bool _retryRefresh = true;
  bool isEditingExpense = false;

  final List<ExpenseEntity> expenses = [];
  final scrollController = ScrollController();

  int get pageSize => 20;

  String? get monthLabel {
    final period = widget.period;
    if (period == null) return null;
    return '${widget.dateFormatter.formatMonth(period.from)} de ${period.from.year}';
  }

  @override
  void initState() {
    super.initState();
    scrollController.addListener(loadNearEnd);
    refreshExpenses();
  }

  @override
  void didUpdateWidget(covariant ExpensesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.deleteCommand != widget.deleteCommand) {
      oldWidget.deleteCommand.dispose();
      pendingDeleteId = null;
      deletingExpenseId = null;
    }

    if (oldWidget.getCommand != widget.getCommand) {
      oldWidget.getCommand.dispose();
      expenses.clear();
      nextPageLink = null;
      isLoading = false;
      hasLoaded = false;
      hasFailure = false;
      pendingDeleteId = null;
      deletingExpenseId = null;
      refreshExpenses();
    }
  }

  @override
  void dispose() {
    scrollController.removeListener(loadNearEnd);
    scrollController.dispose();
    widget.getCommand.dispose();
    widget.deleteCommand.dispose();
    super.dispose();
  }

  void loadNearEnd() {
    if (!scrollController.hasClients || hasFailure || !hasLoaded) return;
    if (scrollController.position.extentAfter < 240.0) loadNextPage();
  }

  Future<void> refreshExpenses() => _loadPage(refresh: true);

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
    setState(() => isEditingExpense = true);

    try {
      final updated = await navigate(id);
      if (!mounted || widget.getCommand != command || updated == null) return;
      widget.onExpensesChanged?.call();

      final index = expenses.indexWhere((expense) => expense.id == id);
      if (index < 0) return;

      setState(() => _applyUpdatedExpense(index, updated));
    } finally {
      if (mounted) setState(() => isEditingExpense = false);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.getCommand == command) loadNearEnd();
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

      if (!mounted ||
          widget.deleteCommand != command ||
          widget.getCommand != queryCommand ||
          !confirmed) {
        return false;
      }

      setState(() => deletingExpenseId = id);
      final data = await command.execute.runAsync(id);
      if (!mounted ||
          widget.deleteCommand != command ||
          widget.getCommand != queryCommand) {
        return false;
      }

      if (data case Right(value: true)) {
        widget.onExpensesChanged?.call();
        deleted = true;
        context.showToast(
          variant: .success,
          title: 'Despesa excluída',
          description: 'A despesa foi removida com sucesso.',
        );
        return true;
      }

      if (data case Left(:final value)) {
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
        return false;
      }

      showDeleteFailure();
      return false;
    } catch (_) {
      if (mounted &&
          widget.deleteCommand == command &&
          widget.getCommand == queryCommand) {
        showDeleteFailure();
      }

      return false;
    } finally {
      if (mounted && widget.deleteCommand == command) {
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
    final period = widget.period;
    if (period == null) return true;

    final day = _civilDay(date);
    return !day.isBefore(_civilDay(period.from)) &&
        !day.isAfter(_civilDay(period.to));
  }

  void _applyUpdatedExpense(int index, ExpenseEntity updated) {
    if (!_isWithinPeriod(updated.occurredOn)) {
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
    setState(() {
      expenses.removeWhere((expense) => expense.id == id);
      pendingDeleteId = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) loadNearEnd();
    });
  }

  Future<void> _loadPage({required bool refresh}) async {
    if (isLoading ||
        isEditingExpense ||
        pendingDeleteId != null ||
        widget.getCommand.execute.isRunning.value) {
      return;
    }
    final command = widget.getCommand;

    setState(() {
      isLoading = true;
      hasFailure = false;
      _retryRefresh = refresh;
    });

    try {
      final data = await command.execute.runAsync((
        pageSize: pageSize,
        to: widget.period?.to,
        from: widget.period?.from,
        pageLink: refresh ? null : nextPageLink,
      ));

      if (!mounted || widget.getCommand != command) return;

      setState(() {
        if (data case Right(:final value)) {
          if (refresh) expenses.clear();
          for (final expense in value.items) {
            _insertExpense(expense);
          }
          nextPageLink = value.next;
          hasLoaded = true;
          return;
        }

        hasFailure = true;
      });
    } catch (_) {
      if (!mounted || widget.getCommand != command) return;
      setState(() => hasFailure = true);
    } finally {
      if (mounted && widget.getCommand == command) {
        setState(() => isLoading = false);
      }
    }

    if (!mounted || widget.getCommand != command || hasFailure) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.getCommand == command) loadNearEnd();
    });
  }
}
