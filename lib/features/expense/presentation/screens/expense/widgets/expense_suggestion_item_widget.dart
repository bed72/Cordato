import 'package:cordato/features/core/presentation/widgets/icons/icon_widget.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/core/presentation/widgets/icons/background_icon_widget.dart';

import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';

final class const ExpenseSuggestionItemWidget({
  super.key,
  required final bool selected,
  required final VoidCallback onTap,
  required final bool hasManualAmount,
  required final IMoneyFormatter moneyFormatter,
  required final ExpenseSuggestionEntity suggestion,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final amount = suggestion.cents;

    return Semantics(
      selected: selected,
      button: true,
      child: BounceWidget.withoutOnPress(
        child: Material(
          color: Color.alphaBlend(
            colors.primary.withValues(alpha: selected ? .1 : .05),
            colors.surfaceContainerLow,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: context.radius.cornerRadius300,
            side: BorderSide(
              color: selected
                  ? colors.primary.withValues(alpha: .35)
                  : colors.outlineVariant.withValues(alpha: .25),
            ),
          ),
          clipBehavior: .antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const .all(16.0),
              child: Row(
                spacing: 12.0,
                children: [
                  ExcludeSemantics(
                    child: BackgroundIconWidget(
                      iconSize: 26.0,
                      iconColor: colors.primary,
                      icon: Icons.auto_awesome_outlined,
                      backgroundColor: colors.primary.withValues(alpha: .12),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      spacing: 4.0,
                      mainAxisSize: .min,
                      crossAxisAlignment: .start,
                      children: [
                        Text(
                          suggestion.description,
                          style: context.typography.bodyMedium?.copyWith(
                            fontWeight: .w600,
                            color: colors.onSurface,
                          ),
                        ),
                        if (amount != null)
                          Text(
                            moneyFormatter.formatCents(amount),
                            style: context.typography.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ExcludeSemantics(
                    child: IconWidget(
                      size: 24.0,
                      icon: Icons.chevron_right,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
