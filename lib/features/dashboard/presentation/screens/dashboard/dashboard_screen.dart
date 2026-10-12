import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

import 'package:cordato/features/insight/presentation/commands/get_insights_command.dart';
import 'package:cordato/features/user/presentation/screens/user/commands/user_command.dart';
import 'package:cordato/features/metrics/presentation/commands/get_expense_metrics_command.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/commands/get_expenses_command.dart';

import 'package:cordato/features/dashboard/presentation/widgets/app_bar_dashboard_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/action_button_dashboard_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/metrics/metrics_section_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/dashboard_month_selector_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/expenses/expenses_section_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/insights/insights_section_widget.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/mixins/dashboard_screen_state_mixin.dart';

final class const DashboardScreen({
  super.key,
  required final UserCommand userCommand,
  required final IDateFormatter dateFormatter,
  required final IMoneyFormatter moneyFormatter,
  required final GetExpensesCommand expensesCommand,
  required final GetInsightsCommand insightsCommand,
  required final GetExpenseMetricsCommand metricsCommand,
  final VoidCallback? onMenuPressed,
  final VoidCallback? onAvatarPressed,
  final VoidCallback? onNotificationsPressed,
  final Future<void> Function()? onExpensePressed,
  final Future<void> Function(DateTime month)? onSeeAllExpensesPressed,
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
          onRefresh: refreshDashboard,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const .only(top: 24.0, bottom: 96.0),
            children: [
              DashboardMonthSelectorWidget(
                selectedMonth: selectedMonth,
                formatter: widget.dateFormatter,
                onPreviousMonth: isLoading ? null : previousMonth,
                onNextMonth: isLoading || !canGoToNextMonth ? null : nextMonth,
              ),
              const SizedBox(height: 8.0),
              MetricsSectionWidget(
                key: ValueKey(('metrics', selectedMonth)),
                command: widget.metricsCommand,
                moneyFormatter: widget.moneyFormatter,
                onRetry: loadMetrics,
              ),
              InsightsSectionWidget(
                key: ValueKey(('insights', selectedMonth)),
                onRetry: loadInsights,
                command: widget.insightsCommand,
              ),
              ExpensesSectionWidget(
                key: ValueKey(('expenses', selectedMonth)),
                onRetry: loadExpenses,
                limit: recentExpensesLimit,
                command: widget.expensesCommand,
                dateFormatter: widget.dateFormatter,
                moneyFormatter: widget.moneyFormatter,
                onSeeAllExpensesPressed: widget.onSeeAllExpensesPressed == null
                    ? null
                    : openExpenses,
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: ActionButtonDashboardWidget(
        onExpense: widget.onExpensePressed == null ? null : openExpense,
      ),
    );
  }
}
