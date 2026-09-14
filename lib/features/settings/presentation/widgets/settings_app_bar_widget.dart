import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/buttons/back_button_widget.dart';

final class SettingsAppBarWidget extends StatelessWidget
    implements PreferredSizeWidget {
  final ValueChanged<BuildContext> onBackPressed;

  const SettingsAppBarWidget({super.key, required this.onBackPressed});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leadingWidth: 72.0,
      leading: BackButtonWidget(onPress: () => onBackPressed(context)),
    );
  }
}
