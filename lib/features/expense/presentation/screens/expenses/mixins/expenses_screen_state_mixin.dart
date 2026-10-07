import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/confirmation_bottom_sheet_widget.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/expenses_screen.dart';

mixin ExpensesScreenStateMixin on State<ExpensesScreen> {
  String? nextPageLink;
  bool isLoading = false;
  bool hasLoaded = false;
  bool hasFailure = false;
  bool _retryRefresh = true;
  String? pendingDeleteId;
  String? deletingExpenseId;

  final List<ExpenseEntity> expenses = [];
  final scrollController = ScrollController();

  int get pageSize => 20;

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
    if (oldWidget.command != widget.command) {
      oldWidget.command.dispose();
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
    widget.command.dispose();
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

  Future<bool> confirmDeleteExpense(String id) async {
    if (isLoading ||
        pendingDeleteId != null ||
        widget.deleteCommand.execute.isRunning.value) {
      return false;
    }

    final command = widget.deleteCommand;
    final queryCommand = widget.command;
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
          widget.command != queryCommand ||
          !confirmed) {
        return false;
      }

      setState(() => deletingExpenseId = id);
      final data = await command.execute.runAsync(id);
      if (!mounted ||
          widget.deleteCommand != command ||
          widget.command != queryCommand) {
        return false;
      }

      if (data case Right(value: true)) {
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
      } else {
        showDeleteFailure();
      }

      return false;
    } catch (_) {
      if (mounted &&
          widget.deleteCommand == command &&
          widget.command == queryCommand) {
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
        pendingDeleteId != null ||
        widget.command.execute.isRunning.value) {
      return;
    }
    final command = widget.command;

    setState(() {
      isLoading = true;
      hasFailure = false;
      _retryRefresh = refresh;
    });

    try {
      final result = await command.execute.runAsync((
        pageSize: pageSize,
        pageLink: refresh ? null : nextPageLink,
      ));

      if (!mounted || widget.command != command) return;

      setState(() {
        if (result case Right(:final value)) {
          if (refresh) expenses.clear();
          expenses.addAll(value.items);
          nextPageLink = value.next;
          hasLoaded = true;
        } else {
          hasFailure = true;
        }
      });
    } catch (_) {
      if (!mounted || widget.command != command) return;
      setState(() => hasFailure = true);
    } finally {
      if (mounted && widget.command == command) {
        setState(() => isLoading = false);
      }
    }

    if (!mounted || widget.command != command || hasFailure) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.command == command) loadNearEnd();
    });
  }
}
