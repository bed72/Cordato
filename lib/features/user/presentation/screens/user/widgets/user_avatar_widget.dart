import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/images/image_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/icon_button_widget.dart';

final class const UserAvatarWidget({
  super.key,
  required final String name,
  final String? imageSource,
  final VoidCallback? onPhotoPressed,
}) extends StatelessWidget {
  String get _initial =>
      name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();

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
              child: imageSource == null || imageSource!.trim().isEmpty
                  ? ColoredBox(
                      color: context.colors.primaryContainer,
                      child: SizedBox.square(
                        dimension: 100.0,
                        child: Center(
                          child: Text(
                            _initial,
                            style: context.typography.headlineLarge?.copyWith(
                              fontWeight: .w700,
                              color: context.colors.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                    )
                  : ImageWidget(
                      fit: .cover,
                      width: 128.0,
                      height: 128.0,
                      alt: 'Foto de $name',
                      source: imageSource,
                    ),
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
                  label: 'Alterar foto',
                  enabled: onPhotoPressed != null,
                  child: IconButtonWidget(
                    width: 36.0,
                    height: 36.0,
                    iconSize: 20.0,
                    onPress: onPhotoPressed,
                    borderRadius: buttonRadius,
                    icon: Icons.camera_alt_outlined,
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
