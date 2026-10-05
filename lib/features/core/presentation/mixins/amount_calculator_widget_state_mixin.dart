import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/expense/presentation/widgets/calculator/amount_calculator_widget.dart';

mixin AmountCalculatorWidgetStateMixin on State<AmountCalculatorWidget> {
  static const _maxWholeDigits = 7;

  late String _input = widget.value > 0
      ? widget.formatter
            .formatCentsWithoutSymbol(widget.value)
            .replaceAll('.', '')
            .replaceFirst(RegExp(r',00$'), '')
      : '';

  int get _value => widget.formatter.parseToCents(_input);
  String get displayValue =>
      _input.isEmpty ? '' : widget.formatter.formatCents(_value);

  void appendDigit(String digit) {
    final parts = _input.split(',');
    final maxDigits = parts.length == 2 ? 2 : _maxWholeDigits;
    if (parts.last.length >= maxDigits) return;

    setState(() => _input = _input == '0' ? digit : '$_input$digit');
  }

  void appendDecimalSeparator() {
    if (_input.contains(',')) return;
    setState(() => _input = '${_input.isEmpty ? '0' : _input},');
  }

  void clear() => setState(() => _input = '');

  void delete() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  void confirm() => Navigator.pop(context, _value > 0 ? _value : null);
}
