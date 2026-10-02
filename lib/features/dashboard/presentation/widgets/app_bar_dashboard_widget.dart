import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/dashboard/presentation/widgets/user/user_name_widget.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/commands/get_user_name_command.dart';
import 'package:cordato/features/dashboard/presentation/widgets/menu_button_dashboard_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/notification_button_dashboard_widget.dart';

final class const AppBarDashboardWidget({
  super.key,
  required final GetUserNameCommand command,
  final VoidCallback? onMenuPressed,
  final VoidCallback? onNotificationsPressed,
}) extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(90.0);

  @override
  Widget build(BuildContext context) => AppBar(
    titleSpacing: 16.0,
    toolbarHeight: preferredSize.height,
    title: UserNameWidget(command: command),
    actions: [
      Padding(
        padding: const EdgeInsets.only(right: 16.0),
        child: Row(
          spacing: 8.0,
          mainAxisSize: .min,
          children: [
            NotificationButtonDashboardWidget(onPress: onNotificationsPressed),
            MenuButtonDashboardWidget(onPress: onMenuPressed),
          ],
        ),
      ),
    ],
  );
}
