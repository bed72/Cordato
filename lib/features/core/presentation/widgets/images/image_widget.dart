import 'package:cordato/features/core/presentation/widgets/images/strategy/asset_image_strategy.dart';
import 'package:cordato/features/core/presentation/widgets/images/strategy/empty_image_strategy.dart';
import 'package:cordato/features/core/presentation/widgets/images/strategy/image_strategy.dart';
import 'package:cordato/features/core/presentation/widgets/images/strategy/network_image_strategy.dart';
import 'package:material_ui/material_ui.dart';

class const ImageWidget({
  super.key,
  required final String? source,
  final String? alt,
  final BoxFit? fit,
  final double? width,
  final Color? color,
  final double? height,
  final String? fallback,
  final bool showLoading = false,
}) extends StatelessWidget {
  ImageStrategy _resolve() => switch (source) {
    null => const EmptyImageStrategy(),
    final data when !data.startsWith('http') => const AssetImageStrategy(),
    _ => const NetworkImageStrategy(),
  };

  @override
  Widget build(BuildContext context) {
    final strategy = _resolve();

    return strategy.build(
      source: source!,
      semanticLabel: alt,
      color: color,
      width: width,
      height: height,
      fallback: fallback,
      fit: fit ?? .cover,
      showLoading: showLoading,
    );
  }
}
