import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class const HeaderWidget({
  super.key,
  required final String title,
  required final String description,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 6.0,
      crossAxisAlignment: .stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: context.typography.headlineMedium?.copyWith(
              color: context.colors.onSurface,
              fontWeight: .w700,
              letterSpacing: -1.0,
            ),
          ),
        ),
        Text(
          description,
          style: context.typography.bodyLarge?.copyWith(
            color: context.colors.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
