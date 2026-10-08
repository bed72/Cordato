import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/buttons/back_button_widget.dart';

final class const ExpenseAppBarWidget({
  super.key,
  required final VoidCallback onBackPressed,
}) extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    leadingWidth: 72.0,
    leading: Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: BackButtonWidget(onPress: onBackPressed),
    ),
  );
}
