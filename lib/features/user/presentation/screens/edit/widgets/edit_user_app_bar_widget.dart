import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/buttons/back_button_widget.dart';

final class const EditUserAppBarWidget({
  super.key,
  required final ValueChanged<BuildContext> onBackPressed,
}) extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    leadingWidth: 72.0,
    leading: BackButtonWidget(onPress: () => onBackPressed(context)),
  );
}
