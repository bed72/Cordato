import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/icons/background_icon_widget.dart';
import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/expense/presentation/extensions/expense_category_extension.dart';

final class const ExpenseItemWidget({
  super.key,
  required final String description,
  required final String formattedDate,
  required final String formattedValue,
  required final ExpenseCategoryEnum category,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Padding(
        padding: const .symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          spacing: 12.0,
          children: [
            ExcludeSemantics(
              child: BackgroundIconWidget(
                icon: category.icon,
                iconColor: category.color(context),
                backgroundColor: category
                    .color(context)
                    .withValues(alpha: 0.12),
              ),
            ),
            Expanded(
              child: Column(
                spacing: 4.0,
                mainAxisSize: .min,
                crossAxisAlignment: .start,
                children: [
                  Text(
                    description,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: context.typography.bodyMedium?.copyWith(
                      fontWeight: .w600,
                      color: context.colors.onSurface,
                    ),
                  ),
                  Text(
                    category.label,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: context.typography.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              fit: .tight,
              child: Column(
                spacing: 4.0,
                mainAxisSize: .min,
                crossAxisAlignment: .end,
                children: [
                  Text(
                    formattedValue,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: context.typography.bodyMedium?.copyWith(
                      fontWeight: .w600,
                      color: context.colors.onSurface,
                    ),
                  ),
                  Text(
                    formattedDate,
                    maxLines: 1,
                    overflow: .ellipsis,
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
