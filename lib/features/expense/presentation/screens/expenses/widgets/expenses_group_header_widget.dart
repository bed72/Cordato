import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class const ExpensesGroupHeaderWidget({
  super.key,
  required final String label,
  final double topSpacing = 16.0,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: .fromLTRB(16.0, topSpacing, 16.0, 4.0),
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: context.typography.titleSmall?.copyWith(
            fontWeight: .w600,
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
