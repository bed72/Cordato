import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/budget/presentation/mixins/budget_amount_calculator_widget_state_mixin.dart';
import 'package:cordato/features/budget/presentation/widgets/calculator/budget_calculator_field_widget.dart';
import 'package:cordato/features/budget/presentation/widgets/calculator/budget_calculator_keyboard_widget.dart';

final class BudgetAmountCalculatorWidget extends StatefulWidget {
  final int value;
  final IMoneyFormatter formatter;

  const BudgetAmountCalculatorWidget({
    super.key,
    required this.value,
    required this.formatter,
  });

  @override
  State<BudgetAmountCalculatorWidget> createState() =>
      _BudgetAmountCalculatorWidgetState();
}

final class _BudgetAmountCalculatorWidgetState
    extends State<BudgetAmountCalculatorWidget>
    with BudgetAmountCalculatorWidgetStateMixin {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .only(top: 6.0),
      child: Column(
        spacing: 16.0,
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [
          BudgetCalculatorFieldWidget(value: displayValue),
          BudgetCalculatorKeyboardWidget(
            onClear: clear,
            onDelete: delete,
            onSubmit: confirm,
            onDigit: appendDigit,
          ),
        ],
      ),
    );
  }
}
