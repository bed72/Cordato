import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class const SummaryCardWidget({
  super.key,
  required final String summary,
  final String title = 'Em resumo',
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: .infinity,
      padding: const .all(20.0),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLow,
        borderRadius: context.radius.cornerRadius300,
        border: .all(color: context.colors.outlineVariant),
      ),
      child: Column(
        spacing: 12.0,
        crossAxisAlignment: .stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: context.typography.titleSmall?.copyWith(
                fontWeight: .w600,
                color: context.colors.primary,
              ),
            ),
          ),
          Text(
            summary,
            style: context.typography.bodyMedium?.copyWith(
              height: 1.6,
              color: context.colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
