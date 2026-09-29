import 'package:flutter_modular/flutter_modular.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/back_button_widget.dart';

final class const AppBarSignUpWidget({super.key})
    extends StatelessWidget
    implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    leadingWidth: 72.0,
    leading: Padding(
      padding: const .only(left: 16.0),
      child: BackButtonWidget(onPress: () => _goBack(context)),
    ),
  );

  void _goBack(BuildContext context) {
    context
      ..dismissKeyboard()
      ..pop();
  }
}
