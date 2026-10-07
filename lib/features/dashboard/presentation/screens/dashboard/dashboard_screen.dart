import 'package:material_ui/material_ui.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';

import 'package:cordato/features/expense/presentation/screens/expenses/commands/get_expenses_command.dart';
import 'package:cordato/features/user/presentation/screens/user/commands/user_command.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';

import 'package:cordato/features/dashboard/presentation/screens/dashboard/mixins/dashboard_screen_state_mixin.dart';
import 'package:cordato/features/dashboard/presentation/widgets/expenses/expenses_section_widget.dart';

import 'package:cordato/features/dashboard/presentation/widgets/app_bar_dashboard_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/action_button_dashboard_widget.dart';

final class const DashboardScreen({
  super.key,
  required final UserCommand userCommand,
  required final IMoneyFormatter formatter,
  required final IDateFormatter dateFormatter,
  required final GetExpensesCommand expensesCommand,
  final VoidCallback? onMenuPressed,
  final VoidCallback? onAvatarPressed,
  final VoidCallback? onBudgetPressed,
  final VoidCallback? onNotificationsPressed,
  final VoidCallback? onSeeAllExpensesPressed,
  final Future<void> Function()? onExpensePressed,
}) extends StatefulWidget {
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

final class _DashboardScreenState extends State<DashboardScreen>
    with DashboardScreenStateMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarDashboardWidget(
        command: widget.userCommand,
        onMenuPressed: widget.onMenuPressed,
        onAvatarPressed: widget.onAvatarPressed,
        onNotificationsPressed: widget.onNotificationsPressed,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refreshExpenses,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const .only(top: 24.0, bottom: 96.0),
            children: [
              ExpensesSectionWidget(
                limit: recentExpensesLimit,
                command: widget.expensesCommand,
                moneyFormatter: widget.formatter,
                dateFormatter: widget.dateFormatter,
                onSeeAllExpensesPressed: widget.onSeeAllExpensesPressed,
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: ExpandableFab.location,
      floatingActionButton: ActionButtonDashboardWidget(
        onBudget: widget.onBudgetPressed,
        onExpense: widget.onExpensePressed == null ? null : openExpense,
      ),
    );
  }
}
