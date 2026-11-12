import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/images/strategy/image_strategy.dart';

final class AssetImageStrategy implements ImageStrategy {
  const AssetImageStrategy();

  @override
  Widget build({
    required String source,
    required bool showLoading,
    required BoxFit? fit,
    required Color? color,
    required double? width,
    required double? height,
    required String? fallback,
    required String? semanticLabel,
  }) {
    return Image.asset(
      source,
      fit: fit,
      color: color,
      width: width,
      height: height,
      isAntiAlias: true,
      alignment: .center,
      filterQuality: .high,
      semanticLabel: semanticLabel ?? 'Local imagem',
      errorBuilder: (_, _, _) => fallback == null
          ? SizedBox(width: width, height: height)
          : Image.asset(fallback, fit: fit, width: width, height: height),
    );
  }
}
