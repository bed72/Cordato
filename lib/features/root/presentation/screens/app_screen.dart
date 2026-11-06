import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/enums/asset_enum.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/images/image_widget.dart';

final class const AppScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final (size, asset) = switch (context.platform) {
      TargetPlatform.android => (288.0, AssetEnum.splashAndroid),
      TargetPlatform.iOS => (168.0, AssetEnum.splashIos),
      _ => (254.0, AssetEnum.logo),
    };

    return Scaffold(
      body: Center(
        child: ImageWidget(
          width: size,
          height: size,
          fit: .contain,
          alt: asset.alt,
          source: asset.source,
        ),
      ),
    );
  }
}
