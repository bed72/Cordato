import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/dashboard/presentation/widgets/user/user_name_widget.dart';
import 'package:cordato/features/dashboard/presentation/commands/get_user_name_command.dart';

final class AppBarDashboardWidget extends StatelessWidget
    implements PreferredSizeWidget {
  final GetUserNameCommand command;

  const AppBarDashboardWidget({super.key, required this.command});

  @override
  Size get preferredSize => const Size.fromHeight(90.0);

  @override
  Widget build(BuildContext context) => AppBar(
    titleSpacing: 16.0,
    toolbarHeight: preferredSize.height,
    title: UserNameWidget(command: command),
  );
}
