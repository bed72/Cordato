import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/widgets/buttons/back_button_widget.dart';

final class AppBarMagicLinkWidget extends StatelessWidget
    implements PreferredSizeWidget {
  const AppBarMagicLinkWidget({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    leadingWidth: 72.0,
    leading: Padding(
      padding: const .only(left: 16.0),
      child: BackButtonWidget(onPress: context.pop),
    ),
  );
}
