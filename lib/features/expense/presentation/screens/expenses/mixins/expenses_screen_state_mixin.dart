import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/formatters/error_message_formatter.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/bottom_sheet_widget.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/confirmation_bottom_sheet_widget.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/enums/category_enum.dart';

import 'package:cordato/features/expense/presentation/screens/expenses/expenses_screen.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_event.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_state.dart';
import 'package:cordato/features/expense/presentation/extensions/expense_category_extension.dart';
import 'package:cordato/features/expense/presentation/formatters/expense_error_message_formatter.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expense_reregistration_widget.dart';

mixin ExpensesScreenStateMixin on State<ExpensesScreen> {
  late ExpensesBloc bloc;
  int? pendingDeleteId;
  int? pendingReregistrationId;
  bool isEditingExpense = false;
  final scrollController = ScrollController();

  List<ExpenseEntity> get expenses => bloc.state.data.items;
  String? get activeCategory => bloc.state.data.category;
  ({DateTime from, DateTime to})? get activePeriod {
    final data = bloc.state.data;

    return data.from != null && data.to != null
        ? (from: data.from!, to: data.to!)
        : null;
  }

  bool get isLoading => bloc.state.isLoading;
  bool get hasFailure => bloc.state is ExpensesFailure;
  bool get hasLoaded => bloc.state.data.hasLoaded;
  int? get deletingExpenseId => switch (bloc.state) {
    ExpensesDeleting(:final id) => id,
    _ => null,
  };
  bool get canRemoveFilters =>
      !bloc.state.isBusy &&
      !isEditingExpense &&
      pendingDeleteId == null &&
      pendingReregistrationId == null;
  String? get categoryLabel => activeCategory == null
      ? null
      : CategoryEnum.values
                .where((value) => value.value == activeCategory)
                .firstOrNull
                ?.label ??
            activeCategory;
  String? get periodLabel {
    final period = activePeriod;

    if (period == null) {
      return null;
    }

    final lastDay = DateTime(period.from.year, period.from.month + 1, 0);
    if (period.from.day != 1 ||
        period.to.year != lastDay.year ||
        period.to.month != lastDay.month ||
        period.to.day != lastDay.day) {
      return widget.dateFormatter.formatShortPeriod(period.from, period.to);
    }
    return '${widget.dateFormatter.formatMonth(period.from)} de ${period.from.year}';
  }

  @override
  void initState() {
    super.initState();
    bloc = widget.bloc();
    scrollController.addListener(loadNearEnd);
    _requestInitial();
  }

  @override
  void didUpdateWidget(ExpensesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = oldWidget.bloc != widget.bloc;
    if (changed) {
      bloc.close();
      bloc = widget.bloc();
    }
    if (changed ||
        oldWidget.category != widget.category ||
        oldWidget.period != widget.period) {
      pendingDeleteId = null;
      pendingReregistrationId = null;
      isEditingExpense = false;
      _requestInitial();
    }
  }

  void _requestInitial() {
    bloc.add(
      ExpensesRequestedEvent(
        category: widget.category,
        from: widget.period?.from,
        to: widget.period?.to,
      ),
    );
    _resetScroll();
  }

  void _resetScroll() {
    final owner = bloc;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && bloc == owner && scrollController.hasClients) {
        scrollController.jumpTo(0);
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    bloc.close();
    super.dispose();
  }

  void handleState(ExpensesState state) {
    switch (state) {
      case ExpensesDeleted():
        _showDeletionSuccess();
      case ExpensesDeleteFailure():
        _showDeletionFailure(state);
      default:
        break;
    }

    if (state.isBusy || state is ExpensesFailure) {
      return;
    }

    _schedulePagination();
  }

  void _showDeletionSuccess() {
    context.showToast(
      variant: .success,
      title: 'Despesa excluída',
      description: 'A despesa foi removida com sucesso.',
    );
  }

  void _showDeletionFailure(ExpensesDeleteFailure failure) {
    context.showToast(
      variant: .error,
      title: 'Erro ao excluir despesa',
      description: ErrorMessageFormatter.formatAll(
        failure.errors.errors,
        fallback: 'Não foi possível excluir a despesa. Tente novamente.',
      ),
    );
  }

  void _schedulePagination() {
    final owner = bloc;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && bloc == owner) {
        loadNearEnd();
      }
    });
  }

  void loadNearEnd() {
    if (!mounted ||
        !scrollController.hasClients ||
        hasFailure ||
        !hasLoaded ||
        !canRemoveFilters) {
      return;
    }
    if (scrollController.position.extentAfter < 240) {
      bloc.add(const ExpensesNextPageRequestedEvent());
    }
  }

  Future<void> refreshExpenses() async {
    if (!canRemoveFilters) {
      return;
    }

    final owner = bloc;
    final completion = owner.stream.firstWhere((state) => !state.isLoading);
    owner.add(
      ExpensesRequestedEvent(
        category: activeCategory,
        from: activePeriod?.from,
        to: activePeriod?.to,
      ),
    );
    try {
      await completion;
    } on StateError {
      return;
    }
  }

  void removeCategoryFilter() {
    if (!canRemoveFilters) {
      return;
    }

    _resetScroll();
    bloc.add(
      ExpensesRequestedEvent(from: activePeriod?.from, to: activePeriod?.to),
    );
  }

  void removePeriodFilter() {
    if (!canRemoveFilters) {
      return;
    }

    _resetScroll();
    bloc.add(ExpensesRequestedEvent(category: activeCategory));
  }

  void retry() {
    if (bloc.state case ExpensesFailure(refresh: false)) {
      bloc.add(const ExpensesNextPageRequestedEvent());
      return;
    }

    refreshExpenses();
  }

  Future<void> editExpense(int id) async {
    if (!canRemoveFilters) {
      return;
    }

    final owner = bloc;
    final data = owner.state.data;
    setState(() => isEditingExpense = true);
    try {
      final updated = await context.pushNamed<ExpenseEntity>(
        RouteEnum.expense.path,
        arguments: id,
      );
      if (!mounted ||
          bloc != owner ||
          owner.state.data != data ||
          updated == null) {
        return;
      }
      owner.add(ExpensesUpdatedEvent(expense: updated));
    } finally {
      if (mounted && bloc == owner) {
        setState(() => isEditingExpense = false);
      }
    }
  }

  void goBack() => context.pop();

  Future<void> confirmDeleteExpense(int id) async {
    if (!canRemoveFilters) {
      return;
    }

    final owner = bloc;
    final data = owner.state.data;
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
      if (!mounted || bloc != owner || owner.state.data != data || !confirmed) {
        return;
      }
      owner.add(ExpensesDeleteRequestedEvent(id: id));
    } finally {
      if (mounted && bloc == owner) {
        setState(() => pendingDeleteId = null);
      }
    }
  }

  Future<void> deleteExpenseAccessibly(int id) async =>
      confirmDeleteExpense(id);

  Future<void> confirmReregisterExpense(ExpenseEntity expense) async {
    if (!canRemoveFilters) {
      return;
    }

    final owner = bloc;
    setState(() => pendingReregistrationId = expense.id);

    try {
      final completion = await showBottomSheetWidget<ExpensesState>(
        context: context,
        title: 'Recadastrar',
        subtitle: 'Recadastre essa despesa com a data atual.',
        enableDrag: false,
        isDismissible: false,
        child: ExpenseReregistrationWidget(bloc: owner, expense: expense),
      );
      if (!mounted || bloc != owner) {
        return;
      }

      _showReregistrationFeedback(completion);
    } finally {
      if (mounted && bloc == owner) {
        setState(() => pendingReregistrationId = null);
      }
    }
  }

  void _showReregistrationFeedback(ExpensesState? completion) {
    switch (completion) {
      case ExpensesReregistered():
        context.showToast(
          variant: .success,
          title: 'Despesa cadastrada',
          description: 'Uma nova despesa foi registrada com a data de hoje.',
        );
      case ExpensesReregisterFailure(:final errors):
        context.showToast(
          variant: .error,
          title: 'Não foi possível cadastrar',
          description: ExpenseErrorMessageFormatter.reregistration(errors),
        );
      default:
        break;
    }
  }
}
