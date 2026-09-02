import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/widgets/icons/background_icon_widget.dart';

final class IconButtonWidget extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final double? width;
  final double? height;
  final Color? iconColor;
  final double? iconSize;
  final VoidCallback? onPress;
  final bool? withoutBackground;
  final BorderRadiusGeometry? borderRadius;

  const IconButtonWidget({
    super.key,
    required this.icon,
    required this.onPress,
    required this.backgroundColor,
    this.width,
    this.iconColor,
    this.height,
    this.iconSize,
    this.borderRadius,
    this.withoutBackground,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = this.iconColor ?? context.colors.primary;
    final resolvedBorderRadius = borderRadius ?? context.radius.cornerRadius100;

    return BounceWidget.withOnPress(
      onPress: onPress,
      child: IconButton(
        padding: .zero,
        icon: BackgroundIconWidget(
          icon: icon,
          width: width,
          height: height,
          iconSize: iconSize,
          iconColor: iconColor,
          backgroundColor: backgroundColor,
          borderRadius: resolvedBorderRadius,
          withoutBackground: withoutBackground,
        ),
        iconSize: iconSize,
        onPressed: onPress,
        constraints: BoxConstraints.tightFor(
          width: width ?? 48.0,
          height: height ?? 48.0,
        ),
        color: iconColor,
        style: IconButton.styleFrom(
          tapTargetSize: .shrinkWrap,
          backgroundColor: Colors.transparent,
          overlayColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: resolvedBorderRadius),
        ),
      ),
    );
  }
}
