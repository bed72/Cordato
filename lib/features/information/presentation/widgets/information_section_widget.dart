import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class const InformationSectionWidget({
  super.key,
  required final String title,
  required final List<String> paragraphs,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 12.0,
      crossAxisAlignment: .stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: context.typography.titleMedium?.copyWith(
              fontWeight: .w600,
              color: context.colors.onSurface,
            ),
          ),
        ),
        for (final paragraph in paragraphs)
          Text(
            paragraph,
            style: context.typography.bodyMedium?.copyWith(
              height: 1.6,
              color: context.colors.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
