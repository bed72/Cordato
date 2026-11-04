import 'package:material_ui/material_ui.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/icons/background_icon_widget.dart';

final class const ExpensesEmptyWidget({super.key}) extends StatelessWidget {
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
                icon: file_text,
                iconColor: context.colors.primary,
                backgroundColor: context.colors.primary.withValues(alpha: 0.12),
              ),
            ),
            Expanded(
              child: Column(
                spacing: 4.0,
                mainAxisSize: .min,
                crossAxisAlignment: .start,
                children: [
                  Text(
                    'Sem despesas neste mês',
                    style: context.typography.labelMedium?.copyWith(
                      fontWeight: .w600,
                      color: context.colors.onSurface,
                    ),
                  ),
                  Text(
                    'Nenhuma despesa registrada no mês selecionado.',
                    style: context.typography.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
