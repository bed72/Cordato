import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/dashboard/presentation/commands/get_user_name_command.dart';
import 'package:cordato/features/dashboard/presentation/widgets/app_bar_dashboard_widget.dart';

final class DashboardScreen extends StatefulWidget {
  final GetUserNameCommand command;

  const DashboardScreen({super.key, required this.command});

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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBarDashboardWidget(command: widget.command),
    body: const SafeArea(child: Center(child: Text('Dashboard'))),
  );
}
