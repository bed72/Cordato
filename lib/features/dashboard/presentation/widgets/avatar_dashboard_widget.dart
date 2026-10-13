import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/user/presentation/widgets/generated_user_avatar_widget.dart';

final class const AvatarDashboardWidget({
  super.key,
  required final String seed,
  final VoidCallback? onPress,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Dados pessoais',
      enabled: onPress != null,
      child: BounceWidget.withOnPress(
        onPress: onPress,
        child: ClipRRect(
          borderRadius: context.radius.cornerRadius100,
          child: GeneratedUserAvatarWidget(seed: seed, size: 48.0),
        ),
      ),
    );
  }
}
