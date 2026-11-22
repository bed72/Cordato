import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/core/presentation/mixins/cents_calculator_widget_state_mixin.dart';

import 'package:cordato/features/expense/presentation/screens/expense/widgets/calculator/cents_calculator_field_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/calculator/cents_calculator_keyboard_widget.dart';

final class const CentsCalculatorWidget({
  super.key,
  required final int value,
  required final IMoneyFormatter formatter,
}) extends StatefulWidget {
  @override
  State<CentsCalculatorWidget> createState() => _CentsCalculatorWidgetState();
}

final class _CentsCalculatorWidgetState extends State<CentsCalculatorWidget>
    with CentsCalculatorWidgetStateMixin {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: Padding(
        padding: const .only(top: 6.0),
        child: Column(
          spacing: 16.0,
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          children: [
            CentsCalculatorFieldWidget(value: displayValue),
            CentsCalculatorKeyboardWidget(
              onClear: clear,
              onDelete: delete,
              onSubmit: confirm,
              onDigit: appendDigit,
              onDecimalSeparator: appendDecimalSeparator,
            ),
          ],
        ),
      ),
    );
  }
}
