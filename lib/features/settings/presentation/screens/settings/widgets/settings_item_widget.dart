import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

import 'package:cordato/features/settings/presentation/screens/settings/widgets/settings_premium_badge_widget.dart';

final class const SettingsItemWidget({
  super.key,
  required final IconData icon,
  required final String label,
  required final VoidCallback? onPressed,
  final bool isPremium = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final content = SizedBox(
      height: 56.0,
      child: Row(
        spacing: 16.0,
        children: [
          Icon(icon, size: 24.0, color: context.colors.onSurfaceVariant),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: .ellipsis,
              style: context.typography.bodyMedium?.copyWith(
                color: context.colors.onSurface,
              ),
            ),
          ),
          if (isPremium) const SettingsPremiumBadgeWidget(),
          Icon(
            Icons.chevron_right,
            size: 24.0,
            color: context.colors.onSurfaceVariant,
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      label: label,
      enabled: onPressed != null,
      child: ExcludeSemantics(
        child: onPressed == null
            ? content
            : BounceWidget.withOnPress(onPress: onPressed, child: content),
      ),
    );
  }
}
