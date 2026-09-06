import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/icon_button_widget.dart';

final class MenuButtonDashboardWidget extends StatelessWidget {
  final VoidCallback? onPress;

  const MenuButtonDashboardWidget({super.key, required this.onPress});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Menu',
    enabled: onPress != null,
    child: ExcludeSemantics(
      child: IconButtonWidget(
        width: 48.0,
        height: 48.0,
        iconSize: 26.0,
        icon: Icons.menu,
        onPress: onPress,
        iconColor: context.colors.onSurface,
        borderRadius: context.radius.cornerRadius100,
        backgroundColor: context.colors.onSurface.withValues(alpha: .02),
      ),
    ),
  );
}
