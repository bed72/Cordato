import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/icon_button_widget.dart';

final class NotificationButtonDashboardWidget extends StatelessWidget {
  final VoidCallback? onPress;

  const NotificationButtonDashboardWidget({super.key, required this.onPress});

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
            backgroundColor: context.colors.onSurface.withValues(alpha: .06),
            backgroundGradient: LinearGradient(
              begin: .topLeft,
              end: .bottomRight,
              colors: [
                Color.lerp(
                  context.colors.surfaceDim,
                  context.colors.onSurface,
                  .0,
                )!,
                Color.lerp(
                  context.colors.surface,
                  context.colors.onSurface,
                  .06,
                )!,
              ],
            ),
          ),
        ),
        Positioned(
          top: 9.0,
          right: 11.0,
          child: ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: .circle,
                color: context.colors.error,
              ),
              child: const SizedBox.square(dimension: 7.0),
            ),
          ),
        ),
      ],
    ),
  );
}
