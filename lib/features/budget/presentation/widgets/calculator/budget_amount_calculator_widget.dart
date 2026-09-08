import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
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
    extends State<BudgetAmountCalculatorWidget> {
  static const _maxDigits = 9;

  late String _digits = widget.value > 0 ? widget.value.toString() : '';

  int get _value => _digits.isEmpty ? 0 : int.parse(_digits);
  String get _displayValue =>
      _digits.isEmpty ? '' : widget.formatter.formatCents(_value);

  void _appendDigit(String digit) {
    if (_digits.length >= _maxDigits) return;
    setState(() => _digits += digit);
  }

  void _clear() => setState(() => _digits = '');

  void _delete() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  void _confirm() => Navigator.of(context).pop(_value > 0 ? _value : null);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .only(top: 6.0),
    child: Column(
      spacing: 16.0,
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      children: [
        BudgetCalculatorFieldWidget(value: _displayValue),
        BudgetCalculatorKeyboardWidget(
          onClear: _clear,
          onDelete: _delete,
          onSubmit: _confirm,
          onDigit: _appendDigit,
        ),
      ],
    ),
  );
}
