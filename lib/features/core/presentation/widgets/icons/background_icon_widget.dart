import 'package:flutter/widgets.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart' as lucide;

import 'package:cordato/features/core/presentation/widgets/icons/icon_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

class const BackgroundIconWidget({
  super.key,
  required final lucide.LucideAnimatedIconData icon,
  required final Color backgroundColor,
  final double? width,
  final double? height,
  final double? iconSize,
  final Color? iconColor,
  final Gradient? gradient,
  final bool? withoutBackground,
  final Gradient? borderGradient,
  final BorderRadiusGeometry? borderRadius,
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
      child: Stack(
        fit: .expand,
        alignment: .center,
        children: [
          Center(
            child: IconWidget(
              key: ValueKey(icon),
              icon: icon,
              size: iconSize,
              color: iconColor,
            ),
          ),
          if (hasBackground && borderGradient != null)
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: borderGradient!.createShader,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius:
                            borderRadius ?? context.radius.cornerRadius100,
                        border: Border.all(color: const Color(0xFFFFFFFF)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
