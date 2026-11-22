import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/icon_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/icons/background_icon_widget.dart';

import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';

final class const ExpenseSuggestionItemWidget({
  super.key,
  required final bool selected,
  required final VoidCallback onTap,
  required final bool hasManualAmount,
  required final VoidCallback onDismiss,
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
              padding: const .fromLTRB(16.0, 16.0, 2.0, 16.0),
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
                          style: context.typography.bodyLarge?.copyWith(
                            fontWeight: .w600,
                            color: colors.onSurface,
                          ),
                        ),
                        if (amount != null)
                          Text(
                            moneyFormatter.formatCents(amount),
                            style: context.typography.bodyMedium?.copyWith(
                              fontWeight: .w500,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Semantics(
                    label: 'Fechar sugestão',
                    child: IconButtonWidget(
                      icon: Icons.close,
                      iconSize: 20.0,
                      iconColor: colors.onSurfaceVariant,
                      backgroundColor: colors.surfaceContainerLow,
                      withoutBackground: true,
                      onPress: onDismiss,
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
