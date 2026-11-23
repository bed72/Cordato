import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/expense_suggestion_item_widget.dart';

final class const ExpenseSuggestionsWidget({
  super.key,
  required final bool hasManualAmount,
  required final VoidCallback onDismiss,
  required final IMoneyFormatter moneyFormatter,
  required final ExpenseSuggestionEntity suggestion,
  required final ValueChanged<ExpenseSuggestionEntity> onSelected,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: math.min(
          constraints.maxHeight,
          320 * MediaQuery.textScalerOf(context).scale(1),
        ),
      ),
      child: ColoredBox(
        color: context.colors.surface,
        child: SingleChildScrollView(
          padding: const .only(top: 8.0, bottom: 16.0),
          child: ExpenseSuggestionItemWidget(
            suggestion: suggestion,
            moneyFormatter: moneyFormatter,
            hasManualAmount: hasManualAmount,
            onTap: () => onSelected(suggestion),
            onDismiss: onDismiss,
            selected: AutocompleteHighlightedOption.of(context) == 0,
          ),
        ),
      ),
    ),
  );
}
