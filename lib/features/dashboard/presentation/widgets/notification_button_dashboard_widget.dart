import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/icon_button_widget.dart';

final class const NotificationButtonDashboardWidget({
  super.key,
  required final VoidCallback? onPress,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Notificações',
    enabled: onPress != null,
    child: Stack(
      clipBehavior: .none,
      children: [
        ExcludeSemantics(
          child: IconButtonWidget(
            width: 48.0,
            height: 48.0,
            iconSize: 26.0,
            onPress: onPress,
            iconColor: context.colors.onSurface,
            icon: Icons.notifications_none_rounded,
            borderRadius: context.radius.cornerRadius100,
            backgroundColor: context.colors.onSurface.withValues(alpha: .02),
          ),
        ),
        _buildDot(context),
      ],
    ),
  );

  Positioned _buildDot(BuildContext context) => Positioned(
    top: 10.0,
    right: 12.0,
    child: ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(shape: .circle, color: context.colors.error),
        child: const SizedBox.square(dimension: 8.0),
      ),
    ),
  );
}
