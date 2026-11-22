import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/expense_suggestion_item_widget.dart';

final class const ExpenseSuggestionsWidget({
  super.key,
  required final bool hasManualAmount,
  required final IMoneyFormatter moneyFormatter,
  required final List<ExpenseSuggestionEntity> suggestions,
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
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: suggestions.length,
        padding: const .symmetric(vertical: 8.0),
        separatorBuilder: (_, _) => const SizedBox(height: 8.0),
        itemBuilder: (context, index) => ExpenseSuggestionItemWidget(
          suggestion: suggestions[index],
          moneyFormatter: moneyFormatter,
          hasManualAmount: hasManualAmount,
          onTap: () => onSelected(suggestions[index]),
          selected: AutocompleteHighlightedOption.of(context) == index,
        ),
      ),
    ),
  );
}
