import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/text_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/icons/background_icon_widget.dart';

final class const ExpensesFailureWidget({
  super.key,
  final VoidCallback? onRetry,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(horizontal: 16.0),
      child: Container(
        padding: const .all(12.0),
        decoration: BoxDecoration(
          borderRadius: context.radius.cornerRadius100,
          color: context.colors.surfaceContainerHighest,
        ),
        child: Row(
          spacing: 12.0,
          children: [
            ExcludeSemantics(
              child: BackgroundIconWidget(
                iconSize: 20.0,
                icon: Icons.error_outline,
                iconColor: context.colors.error,
                backgroundColor: context.colors.error.withValues(alpha: 0.12),
              ),
            ),
            Expanded(
              child: Column(
                spacing: 4.0,
                mainAxisSize: .min,
                crossAxisAlignment: .start,
                children: [
                  Text(
                    'Não foi possível carregar as despesas.',
                    style: context.typography.labelMedium?.copyWith(
                      fontWeight: .w600,
                      color: context.colors.onSurface,
                    ),
                  ),
                  Text(
                    'Suas despesas estão indisponíveis no momento.',
                    style: context.typography.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  if (onRetry != null)
                    TextButtonWidget(label: 'Tentar novamente', onTap: onRetry),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
