import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/calculator/amount_calculator_key_widget.dart';

final class AmountCalculatorKeyboardWidget extends StatelessWidget {
  final VoidCallback onClear;
  final VoidCallback onDelete;
  final VoidCallback onSubmit;
  final ValueChanged<String> onDigit;

  const AmountCalculatorKeyboardWidget({
    super.key,
    required this.onDigit,
    required this.onClear,
    required this.onDelete,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 290.0,
      child: Row(
        spacing: 4.0,
        crossAxisAlignment: .stretch,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              spacing: 4.0,
              children: [
                _buildDigitRow(const ['7', '8', '9']),
                _buildDigitRow(const ['4', '5', '6']),
                _buildDigitRow(const ['1', '2', '3']),
                Expanded(
                  child: AmountCalculatorKeyWidget(
                    label: '0',
                    onTap: () => onDigit('0'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              spacing: 4.0,
              children: [
                Expanded(
                  child: AmountCalculatorKeyWidget(
                    label: 'DEL',
                    isAction: true,
                    onTap: onDelete,
                  ),
                ),
                Expanded(
                  child: AmountCalculatorKeyWidget(
                    label: 'AC',
                    isAction: true,
                    onTap: onClear,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: AmountCalculatorKeyWidget(
                    label: '✓',
                    isAction: true,
                    onTap: onSubmit,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDigitRow(List<String> digits) => Expanded(
    child: Row(
      spacing: 4.0,
      children: [
        for (final digit in digits)
          Expanded(
            child: AmountCalculatorKeyWidget(
              label: digit,
              onTap: () => onDigit(digit),
            ),
          ),
      ],
    ),
  );
}
