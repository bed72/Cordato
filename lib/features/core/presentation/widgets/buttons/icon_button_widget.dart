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
  final Gradient? backgroundGradient;
  final BorderRadiusGeometry? borderRadius;

  const IconButtonWidget({
    super.key,
    required this.icon,
    required this.onPress,
    required this.backgroundColor,
    this.width,
    this.height,
    this.iconSize,
    this.iconColor,
    this.borderRadius,
    this.withoutBackground,
    this.backgroundGradient,
  });

  @override
  Widget build(BuildContext context) {
    return BounceWidget.withOnPress(
      onPress: onPress,
      child: IconButton(
        padding: .zero,
        color: iconColor,
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
          iconColor: iconColor,
          borderRadius: borderRadius,
          gradient: backgroundGradient,
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
    );
  }
}
