import 'package:material_ui/material_ui.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart' as lucide;

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/icon_button_widget.dart';

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
        child: IconButtonWidget(
          width: 48.0,
          height: 48.0,
          iconSize: 24.0,
          onPress: onPress == null
              ? null
              : () {
                  context.dismissKeyboard();
                  onPress!();
                },
          icon: lucide.chevron_left,
          withoutBackground: false,
          iconColor: onPress == null
              ? context.colors.onSurfaceVariant
              : context.colors.onSurface,
          borderRadius: context.radius.cornerRadius100,
          backgroundColor: context.colors.surfaceContainerLowest,
          backgroundGradient: LinearGradient(
            begin: .topLeft,
            end: .bottomRight,
            colors: [
              context.colors.surfaceContainerLowest,
              context.colors.surface,
            ],
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
        ),
      ),
    );
  }
}
