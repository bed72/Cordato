import 'package:cordato/features/core/presentation/widgets/images/strategy/asset_image_strategy.dart';
import 'package:material_ui/material_ui.dart';

class const ImageWidget({
  super.key,
  required final String source,
  final String? alt,
  final BoxFit? fit,
  final double? width,
  final Color? color,
  final double? height,
  final String? fallback,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const AssetImageStrategy().build(
      source: source,
      semanticLabel: alt,
      color: color,
      width: width,
      height: height,
      fallback: fallback,
      fit: fit ?? .cover,
    );
  }
}
