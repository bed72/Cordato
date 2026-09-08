import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/budget/presentation/widgets/calculator/budget_calculator_key_widget.dart';

final class BudgetCalculatorKeyboardWidget extends StatelessWidget {
  final VoidCallback onClear;
  final VoidCallback onDelete;
  final VoidCallback onSubmit;
  final ValueChanged<String> onDigit;

  const BudgetCalculatorKeyboardWidget({
    super.key,
    required this.onDigit,
    required this.onClear,
    required this.onDelete,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
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
                child: BudgetCalculatorKeyWidget(
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
                child: BudgetCalculatorKeyWidget(
                  label: 'DEL',
                  isAction: true,
                  onTap: onDelete,
                ),
              ),
              Expanded(
                child: BudgetCalculatorKeyWidget(
                  label: 'AC',
                  isAction: true,
                  onTap: onClear,
                ),
              ),
              Expanded(
                flex: 2,
                child: BudgetCalculatorKeyWidget(
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

  Widget _buildDigitRow(List<String> digits) => Expanded(
    child: Row(
      spacing: 4.0,
      children: [
        for (final digit in digits)
          Expanded(
            child: BudgetCalculatorKeyWidget(
              label: digit,
              onTap: () => onDigit(digit),
            ),
          ),
      ],
    ),
  );
}
