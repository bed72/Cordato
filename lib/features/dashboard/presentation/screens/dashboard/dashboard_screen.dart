import 'package:material_ui/material_ui.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';

import 'package:cordato/features/user/presentation/screens/user/commands/user_command.dart';

import 'package:cordato/features/dashboard/presentation/widgets/app_bar_dashboard_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/action_button_dashboard_widget.dart';

final class const DashboardScreen({
  super.key,
  required final UserCommand command,
  final VoidCallback? onAvatarPressed,
  final VoidCallback? onMenuPressed,
  final VoidCallback? onBudgetPressed,
  final VoidCallback? onExpensePressed,
  final VoidCallback? onNotificationsPressed,
}) extends StatefulWidget {
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

final class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    widget.command.execute.run();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarDashboardWidget(
        command: widget.command,
        onAvatarPressed: widget.onAvatarPressed,
        onMenuPressed: widget.onMenuPressed,
        onNotificationsPressed: widget.onNotificationsPressed,
      ),
      body: const SafeArea(child: Center(child: Text('Dashboard'))),
      floatingActionButtonLocation: ExpandableFab.location,
      floatingActionButton: ActionButtonDashboardWidget(
        onBudget: widget.onBudgetPressed,
        onExpense: widget.onExpensePressed,
      ),
    );
  }
}
