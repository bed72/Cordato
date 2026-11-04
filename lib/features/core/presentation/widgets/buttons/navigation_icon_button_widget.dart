import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/icon_button_widget.dart';

final class const NavigationIconButtonWidget({
  super.key,
  required final IconData icon,
  required final VoidCallback? onPress,
  final double iconSize = 24.0,
  final Color? iconColor,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => IconButtonWidget(
    width: 48.0,
    height: 48.0,
    icon: icon,
    onPress: onPress,
    iconSize: iconSize,
    withoutBackground: false,
    iconColor: iconColor ?? context.colors.onSurface,
    borderRadius: context.radius.cornerRadius100,
    backgroundColor: context.colors.surfaceContainerLowest,
    backgroundGradient: LinearGradient(
      begin: .topLeft,
      end: .bottomRight,
      colors: [context.colors.surfaceContainerLowest, context.colors.surface],
    ),
    borderGradient: LinearGradient(
      begin: .topLeft,
      end: .bottomRight,
      stops: const [0.0, .45, 1.0],
      colors: [
        context.colors.onSurface.withValues(alpha: 0.0),
        context.colors.onSurface.withValues(alpha: 0.0),
        context.colors.onSurface.withValues(alpha: .28),
      ],
    ),
  );
}
