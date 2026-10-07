import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/expenses_screen.dart';

mixin ExpensesScreenStateMixin on State<ExpensesScreen> {
  String? nextPageLink;
  bool isLoading = false;
  bool hasLoaded = false;
  bool hasFailure = false;
  bool _retryRefresh = true;

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
    if (oldWidget.command != widget.command) {
      oldWidget.command.dispose();
      expenses.clear();
      nextPageLink = null;
      isLoading = false;
      hasLoaded = false;
      hasFailure = false;
      refreshExpenses();
    }
  }

  @override
  void dispose() {
    scrollController.removeListener(loadNearEnd);
    scrollController.dispose();
    widget.command.dispose();
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

  Future<void> _loadPage({required bool refresh}) async {
    if (isLoading || widget.command.execute.isRunning.value) return;
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
