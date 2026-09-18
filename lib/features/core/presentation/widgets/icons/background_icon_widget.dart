import 'package:flutter/widgets.dart';

import 'package:cordato/features/core/presentation/widgets/icons/icon_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

class const BackgroundIconWidget({
  super.key,
  required final IconData icon,
  required final Color backgroundColor,
  final double? width,
  final double? height,
  final double? iconSize,
  final Gradient? gradient,
  final Color? iconColor,
  final BorderRadiusGeometry? borderRadius,
  final bool? withoutBackground,
}) extends StatelessWidget {
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
