import 'package:flutter/material.dart';

import 'package:cordato/features/core/presentation/widgets/icons/icon_widget.dart';
import 'package:cordato/features/core/presentation/widgets/images/strategy/image_strategy.dart';

final class EmptyImageStrategy implements ImageStrategy {
  const EmptyImageStrategy();

  @override
  Widget build({
    required String source,
    required BoxFit? fit,
    required Color? color,
    required double? width,
    required double? height,
    required bool showLoading,
    required String? fallback,
    required String? semanticLabel,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: IconWidget(
        color: color ?? Colors.grey,
        icon: Icons.hourglass_empty_rounded,
        size: (width ?? height ?? 48) * 0.6,
        semanticsLabel: semanticLabel ?? 'Sem imagem',
      ),
    );
  }
}
