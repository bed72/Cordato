import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class const BudgetHeaderWidget({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    spacing: 6.0,
    crossAxisAlignment: .stretch,
    children: [
      Semantics(
        header: true,
        child: Text(
          'Quanto você quer gastar?',
          style: context.typography.headlineMedium?.copyWith(
            fontWeight: .w700,
            letterSpacing: -1.0,
            color: context.colors.onSurface,
          ),
        ),
      ),
      Text(
        'Defina um valor e por quanto tempo você pretende usá-lo.',
        style: context.typography.bodyLarge?.copyWith(
          color: context.colors.onSurfaceVariant.withValues(alpha: 0.8),
        ),
      ),
    ],
  );
}
