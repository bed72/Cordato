import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/navigation_icon_button_widget.dart';

final class const BackButtonWidget({
  super.key,
  required final VoidCallback? onPress,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Voltar',
      child: Opacity(
        opacity: onPress == null ? .55 : 1.0,
        child: NavigationIconButtonWidget(
          onPress: onPress == null
              ? null
              : () {
                  context.dismissKeyboard();
                  onPress!();
                },
          icon: Icons.chevron_left,
          iconColor: onPress == null
              ? context.colors.onSurfaceVariant
              : context.colors.onSurface,
        ),
      ),
    );
  }
}
