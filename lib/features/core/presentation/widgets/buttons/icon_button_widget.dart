import 'package:material_ui/material_ui.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart' as lucide;

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/widgets/icons/background_icon_widget.dart';
import 'package:cordato/features/core/presentation/widgets/icons/icon_interaction_widget.dart';

final class const IconButtonWidget({
  super.key,
  required final lucide.LucideAnimatedIconData icon,
  required final VoidCallback? onPress,
  required final Color backgroundColor,
  final double? width,
  final double? height,
  final double? iconSize,
  final Color? iconColor,
  final bool? withoutBackground,
  final Gradient? borderGradient,
  final Gradient? backgroundGradient,
  final BorderRadiusGeometry? borderRadius,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconInteractionWidget(
      enabled: onPress != null,
      child: BounceWidget.withOnPress(
        onPress: onPress,
        child: IconButton(
          padding: .zero,
          color: iconColor,
          disabledColor: Color.lerp(
            iconColor ?? context.colors.primary,
            context.colors.surface,
            .25,
          ),
          iconSize: iconSize,
          onPressed: onPress,
          constraints: BoxConstraints.tightFor(
            width: width ?? 48.0,
            height: height ?? 48.0,
          ),
          icon: BackgroundIconWidget(
            icon: icon,
            width: width,
            height: height,
            iconSize: iconSize,
            iconColor: onPress == null
                ? Color.lerp(
                    iconColor ?? context.colors.primary,
                    context.colors.surface,
                    .25,
                  )
                : iconColor,
            borderRadius: borderRadius,
            gradient: backgroundGradient,
            borderGradient: borderGradient,
            backgroundColor: backgroundColor,
            withoutBackground: withoutBackground,
          ),
          style: IconButton.styleFrom(
            tapTargetSize: .shrinkWrap,
            overlayColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: borderRadius ?? context.radius.cornerRadius100,
            ),
          ),
        ),
      ),
    );
  }
}
