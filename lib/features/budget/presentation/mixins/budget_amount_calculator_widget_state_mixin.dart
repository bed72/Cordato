import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/budget/presentation/widgets/calculator/budget_amount_calculator_widget.dart';

mixin BudgetAmountCalculatorWidgetStateMixin
    on State<BudgetAmountCalculatorWidget> {
  static const _maxDigits = 9;

  late String _digits = widget.value > 0 ? widget.value.toString() : '';

  int get _value => _digits.isEmpty ? 0 : int.parse(_digits);
  String get displayValue =>
      _digits.isEmpty ? '' : widget.formatter.formatCents(_value);

  void appendDigit(String digit) {
    if (_digits.length >= _maxDigits) return;
    setState(() => _digits += digit);
  }

  void clear() => setState(() => _digits = '');

  void delete() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  void confirm() => context.pop(_value > 0 ? _value : null);
}
