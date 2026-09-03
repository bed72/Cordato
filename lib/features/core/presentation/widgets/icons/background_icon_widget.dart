import 'package:flutter/widgets.dart';

import 'package:cordato/features/core/presentation/widgets/icons/icon_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

class BackgroundIconWidget extends StatelessWidget {
  final Color backgroundColor;
  final IconData icon;
  final double? width;
  final double? height;
  final double? iconSize;
  final Color? iconColor;
  final Gradient? gradient;
  final bool? withoutBackground;
  final BorderRadiusGeometry? borderRadius;

  const BackgroundIconWidget({
    super.key,
    required this.icon,
    required this.backgroundColor,
    this.width,
    this.height,
    this.iconSize,
    this.gradient,
    this.iconColor,
    this.borderRadius,
    this.withoutBackground,
  });

  @override
  Widget build(BuildContext context) {
    final hasBackground = !(withoutBackground ?? false);

    return Container(
      alignment: .center,
      width: width ?? 48.0,
      height: height ?? 48.0,
      decoration: BoxDecoration(
        gradient: hasBackground ? gradient : null,
        borderRadius: borderRadius ?? context.radius.cornerRadius100,
        color: hasBackground && gradient == null ? backgroundColor : null,
      ),
      child: IconWidget(icon: icon, color: iconColor, size: iconSize),
    );
  }
}
