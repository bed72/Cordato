import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/icon_button_widget.dart';
import 'package:cordato/features/user/presentation/widgets/generated_user_avatar_widget.dart';

final class const UserAvatarWidget({
  super.key,
  required final String name,
  required final String seed,
  final VoidCallback? onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const borderWidth = 3.0;
    final buttonRadius = context.radius.cornerRadius050;

    return SizedBox(
      width: 128.0,
      height: 128.0,
      child: Stack(
        children: [
          Semantics(
            image: true,
            label: 'Avatar de $name',
            child: ClipRRect(
              borderRadius: context.radius.cornerRadius300,
              child: GeneratedUserAvatarWidget(seed: seed, size: 100.0),
            ),
          ),
          Positioned(
            right: 14.0,
            bottom: 14.0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerLowest,
                borderRadius: buttonRadius + .circular(borderWidth),
              ),
              child: Padding(
                padding: const .all(borderWidth),
                child: Semantics(
                  button: true,
                  enabled: onPressed != null,
                  label: 'Gerar outro avatar',
                  child: IconButtonWidget(
                    width: 36.0,
                    height: 36.0,
                    iconSize: 20.0,
                    onPress: onPressed,
                    icon: Icons.refresh,
                    borderRadius: buttonRadius,
                    iconColor: context.colors.onPrimary,
                    backgroundColor: context.colors.primary,
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
