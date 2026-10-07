import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/dashboard/presentation/screens/dashboard/dashboard_screen.dart';

mixin DashboardScreenStateMixin on State<DashboardScreen> {
  int get recentExpensesLimit => 6;

  @override
  void initState() {
    super.initState();
    widget.userCommand.execute.run();
    loadExpenses();
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
  }

  @override
  void dispose() {
    widget.expensesCommand.dispose();
    super.dispose();
  }

  void loadExpenses() => widget.expensesCommand.execute.run((
    pageLink: null,
    pageSize: recentExpensesLimit,
  ));

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
  }
}
