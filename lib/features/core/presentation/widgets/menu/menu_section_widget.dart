import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class const MenuSectionWidget({
  super.key,
  required final String label,
  required final Widget child,
  final double spacing = 8.0,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: spacing,
      crossAxisAlignment: .stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            label.toUpperCase(),
            style: context.typography.labelSmall?.copyWith(
              fontWeight: .w600,
              letterSpacing: 1.2,
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
        child,
      ],
    );
  }
}
