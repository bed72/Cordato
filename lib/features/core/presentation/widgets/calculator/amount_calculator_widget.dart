import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/core/presentation/mixins/amount_calculator_widget_state_mixin.dart';
import 'package:cordato/features/core/presentation/widgets/calculator/amount_calculator_field_widget.dart';
import 'package:cordato/features/core/presentation/widgets/calculator/amount_calculator_keyboard_widget.dart';

final class AmountCalculatorWidget extends StatefulWidget {
  final int value;
  final IMoneyFormatter formatter;

  const AmountCalculatorWidget({
    super.key,
    required this.value,
    required this.formatter,
  });

  @override
  State<AmountCalculatorWidget> createState() => _AmountCalculatorWidgetState();
}

final class _AmountCalculatorWidgetState extends State<AmountCalculatorWidget>
    with AmountCalculatorWidgetStateMixin {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Column(
        spacing: 16.0,
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [
          AmountCalculatorFieldWidget(value: displayValue),
          AmountCalculatorKeyboardWidget(
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
