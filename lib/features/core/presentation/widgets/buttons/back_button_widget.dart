import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/icon_button_widget.dart';

final class const BackButtonWidget({
  super.key,
  required final VoidCallback? onPress,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => IconButtonWidget(
    width: 48.0,
    height: 48.0,
    iconSize: 26.0,
    onPress: onPress == null
        ? null
        : () {
            context.dismissKeyboard();
            onPress!();
          },
    icon: Icons.chevron_left,
    withoutBackground: false,
    iconColor: context.colors.onSurface,
    borderRadius: context.radius.cornerRadius100,
    backgroundColor: context.colors.onSurface.withValues(alpha: .04),
  );
}
