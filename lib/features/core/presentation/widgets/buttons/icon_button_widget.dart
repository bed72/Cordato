import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/widgets/icons/background_icon_widget.dart';

final class const IconButtonWidget({
  super.key,
  required final IconData icon,
  required final VoidCallback? onPress,
  required final Color backgroundColor,
  final double? width,
  final double? height,
  final double? iconSize,
  final Color? iconColor,
  final BorderRadiusGeometry? borderRadius,
  final bool? withoutBackground,
  final Gradient? backgroundGradient,
}) extends StatelessWidget {
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
