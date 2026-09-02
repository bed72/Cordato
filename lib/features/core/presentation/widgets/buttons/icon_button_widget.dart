import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';

final class IconButtonWidget extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double? width;
  final double? height;
  final double? iconSize;
  final VoidCallback? onPress;
  final bool? withoutBackground;
  final BorderRadiusGeometry? borderRadius;

  const IconButtonWidget({
    super.key,
    required this.icon,
    required this.onPress,
    this.width,
    this.color,
    this.height,
    this.iconSize,
    this.borderRadius,
    this.withoutBackground,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? context.colors.primary;
    final resolvedBorderRadius = borderRadius ?? context.radius.cornerRadius100;

    return BounceWidget.withOnPress(
      onPress: onPress,
      child: IconButton(
        padding: .zero,
        icon: Icon(icon),
        iconSize: iconSize,
        onPressed: onPress,
        constraints: BoxConstraints.tightFor(
          width: width ?? 48.0,
          height: height ?? 48.0,
        ),
        color: iconColor,
        style: IconButton.styleFrom(
          tapTargetSize: .shrinkWrap,
          backgroundColor: withoutBackground == true
              ? Colors.transparent
              : iconColor.withValues(alpha: 0.2),
          shape: RoundedRectangleBorder(borderRadius: resolvedBorderRadius),
        ),
      ),
    );
  }
}
