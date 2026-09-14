import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class SettingsSectionWidget extends StatelessWidget {
  final String label;

  const SettingsSectionWidget({super.key, required this.label});

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
