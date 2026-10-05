import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/widgets/icons/background_icon_widget.dart';

final class const SettingsInvitePartnerWidget({
  super.key,
  required final VoidCallback? onInvitePartnerPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final content = Card(
      margin: .zero,
      color: context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: context.radius.cornerRadius100,
      ),
      child: Padding(
        padding: const .all(12.0),
        child: Row(
          spacing: 12.0,
          children: [
            BackgroundIconWidget(
              iconSize: 24.0,
              icon: Icons.person_add_alt,
              iconColor: context.colors.onPrimaryContainer,
              backgroundColor: context.colors.primaryContainer,
            ),
            Expanded(
              child: Column(
                spacing: 2.0,
                mainAxisSize: .min,
                crossAxisAlignment: .start,
                children: [
                  Text(
                    'Convidar parceiro',
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: context.typography.bodyMedium?.copyWith(
                      color: context.colors.onSurface,
                      fontWeight: .w700,
                    ),
                  ),
                  Text(
                    'Comecem a usar juntos',
                    maxLines: 2,
                    overflow: .ellipsis,
                    style: context.typography.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 24.0,
              color: context.colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: onInvitePartnerPressed != null,
      label: 'Convidar parceiro',
      child: ExcludeSemantics(
        child: onInvitePartnerPressed == null
            ? content
            : BounceWidget.withOnPress(
                onPress: onInvitePartnerPressed,
                child: content,
              ),
      ),
    );
  }
}
