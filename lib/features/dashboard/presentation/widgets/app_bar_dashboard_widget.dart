import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';

import 'package:cordato/features/dashboard/presentation/widgets/user/user_name_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/menu_button_dashboard_widget.dart';

final class const AppBarDashboardWidget({
  super.key,
  required final UserEntity? user,
  final bool isLoading = false,
}) extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(64.0);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 16.0,
      toolbarHeight: preferredSize.height,
      title: UserNameWidget(user: user, isLoading: isLoading),
      actions: [
        Padding(
          padding: const .only(right: 16.0),
          child: const MenuButtonDashboardWidget(),
        ),
      ],
    );
  }
}
