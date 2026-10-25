import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/enums/asset_enum.dart';
import 'package:cordato/features/core/presentation/widgets/images/image_widget.dart';

final class const AppScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ImageWidget(
            width: 254,
            height: 254,
            fit: .contain,
            alt: AssetEnum.logo.alt,
            source: AssetEnum.logo.source,
          ),
        ),
      ),
    );
  }
}
