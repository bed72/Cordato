import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/enums/asset_enum.dart';
import 'package:cordato/features/core/presentation/widgets/images/image_widget.dart';

final class const WelcomeIconWidget({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 254.0,
    height: 254.0,
    child: Center(
      child: ImageWidget(
        fit: .contain,
        alt: AssetEnum.logo.alt,
        source: AssetEnum.logo.source,
      ),
    ),
  );
}
