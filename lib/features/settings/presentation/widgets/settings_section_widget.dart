import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class const SettingsSectionWidget({
  super.key,
  required final String label,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        label.toUpperCase(),
        style: context.typography.labelSmall?.copyWith(
          fontWeight: .w600,
          letterSpacing: 1.2,
          color: context.colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
