import 'package:material_ui/material_ui.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/icons/background_icon_widget.dart';

final class const IformationCardContentWidget({
  super.key,
  required final String title,
  required final LucideAnimatedIconData icon,
  required final Color iconColor,
  required final String description,
  required final Color iconBackgroundColor,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 12.0,
      children: [
        ExcludeSemantics(
          child: BackgroundIconWidget(
            icon: icon,
            iconSize: 24.0,
            iconColor: iconColor,
            backgroundColor: iconBackgroundColor,
          ),
        ),
        Expanded(
          child: Column(
            spacing: 2.0,
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            children: [
              Text(
                title,
                style: context.typography.bodyMedium?.copyWith(
                  fontWeight: .w700,
                  color: context.colors.onSurface,
                ),
              ),
              Text(
                description,
                style: context.typography.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
