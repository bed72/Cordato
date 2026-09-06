import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/icon_button_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/user/user_name_widget.dart';
import 'package:cordato/features/dashboard/presentation/commands/get_user_name_command.dart';

final class AppBarDashboardWidget extends StatelessWidget
    implements PreferredSizeWidget {
  final GetUserNameCommand command;
  final VoidCallback? onMenuPressed;
  final VoidCallback? onNotificationsPressed;

  const AppBarDashboardWidget({
    super.key,
    required this.command,
    this.onMenuPressed,
    this.onNotificationsPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(90.0);

  @override
  Widget build(BuildContext context) => AppBar(
    titleSpacing: 16.0,
    toolbarHeight: preferredSize.height,
    title: UserNameWidget(command: command),
    actions: [_notificationButton(context), _menuButton(context)],
  );

  Widget _notificationButton(BuildContext context) => Semantics(
    button: true,
    label: 'Notificações',
    enabled: onNotificationsPressed != null,
    child: Stack(
      clipBehavior: .none,
      children: [
        ExcludeSemantics(
          child: IconButtonWidget(
            withoutBackground: true,
            onPress: onNotificationsPressed,
            iconColor: context.colors.onSurface,
            backgroundColor: Colors.transparent,
            icon: Icons.notifications_none_rounded,
          ),
        ),
        Positioned(
          top: 9.0,
          right: 11.0,
          child: ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: .circle,
                color: context.colors.error,
              ),
              child: const SizedBox.square(dimension: 7.0),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _menuButton(BuildContext context) => Semantics(
    button: true,
    label: 'Menu',
    enabled: onMenuPressed != null,
    child: ExcludeSemantics(
      child: IconButtonWidget(
        icon: Icons.menu,
        onPress: onMenuPressed,
        withoutBackground: true,
        iconColor: context.colors.onSurface,
        backgroundColor: Colors.transparent,
      ),
    ),
  );
}
