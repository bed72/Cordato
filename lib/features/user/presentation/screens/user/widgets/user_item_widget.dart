import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';

final class const UserItemWidget({
  super.key,
  required final String label,
  required final String value,
  required final IconData icon,
  final VoidCallback? onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final content = Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: SizedBox(
        height: 64.0,
        child: Row(
          spacing: 12.0,
          children: [
            Icon(icon, size: 24.0, color: context.colors.onSurfaceVariant),
            Text(
              label,
              style: context.typography.bodyMedium?.copyWith(
                color: context.colors.onSurface,
              ),
            ),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: .ellipsis,
                textAlign: .end,
                style: context.typography.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
            if (enabled)
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
      label: label,
      value: value,
      button: true,
      enabled: enabled,
      child: ExcludeSemantics(
        child: enabled
            ? BounceWidget.withOnPress(onPress: onPressed, child: content)
            : content,
      ),
    );
  }
}
