import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/outline_button_widget.dart';

final class const ExpensesFeedbackWidget({
  super.key,
  required final String title,
  required final String description,
  final VoidCallback? onRetry,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .all(24.0),
      child: Column(
        spacing: 12.0,
        mainAxisSize: .min,
        children: [
          Text(
            title,
            textAlign: .center,
            style: context.typography.titleMedium,
          ),
          Text(
            description,
            textAlign: .center,
            style: context.typography.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          if (onRetry != null)
            OutlineButtonWidget(label: 'Tentar novamente', onTap: onRetry),
        ],
      ),
    );
  }
}
