import 'package:flutter_boring_avatars/flutter_boring_avatars.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/themes/color_theme.dart';

final class const GeneratedUserAvatarWidget({
  super.key,
  required final String seed,
  required final double size,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: AnimatedBoringAvatar(
        name: seed,
        type: BoringAvatarType.marble,
        duration: const Duration(milliseconds: 300),
        palette: BoringAvatarPalette([
          lightColors.primary,
          lightColors.primarySoft,
          lightColors.textOnSuccess,
          lightColors.info,
          lightColors.warning,
        ]),
        shape: const RoundedRectangleBorder(),
      ),
    );
  }
}
