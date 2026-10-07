import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/expense/presentation/screens/create_expense/widgets/calculator/cents_calculator_key_widget.dart';

final class const CentsCalculatorKeyboardWidget({
  super.key,
  required final VoidCallback onClear,
  required final VoidCallback onDelete,
  required final VoidCallback onSubmit,
  required final ValueChanged<String> onDigit,
  required final VoidCallback onDecimalSeparator,
}) extends StatelessWidget {
  static const _keyCount = 4.0;
  static const _keySpacing = 4.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacingSize = _keySpacing * (_keyCount - 1.0);
        final keySizeByWidth = (constraints.maxWidth - spacingSize) / _keyCount;
        final keySizeByHeight = constraints.hasBoundedHeight
            ? (constraints.maxHeight - spacingSize) / _keyCount
            : keySizeByWidth;
        final keySize = math.min(keySizeByWidth, keySizeByHeight);
        final keyboardHeight = (keySize * _keyCount) + spacingSize;
        final digitColumnWidth = (keySize * 3.0) + (_keySpacing * 2.0);

        return SizedBox(
          height: keyboardHeight,
          child: Row(
            spacing: _keySpacing,
            crossAxisAlignment: .stretch,
            children: [
              SizedBox(
                width: digitColumnWidth,
                child: Column(
                  spacing: _keySpacing,
                  children: [
                    _buildDigitRow(const ['7', '8', '9']),
                    _buildDigitRow(const ['4', '5', '6']),
                    _buildDigitRow(const ['1', '2', '3']),
                    Expanded(
                      child: Row(
                        spacing: _keySpacing,
                        children: [
                          Expanded(
                            flex: 2,
                            child: CentsCalculatorKeyWidget(
                              label: '0',
                              onTap: () => onDigit('0'),
                            ),
                          ),
                          Expanded(
                            child: CentsCalculatorKeyWidget(
                              label: ',',
                              onTap: onDecimalSeparator,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  spacing: _keySpacing,
                  children: [
                    Expanded(
                      child: CentsCalculatorKeyWidget(
                        label: 'DEL',
                        isAction: true,
                        onTap: onDelete,
                      ),
                    ),
                    Expanded(
                      child: CentsCalculatorKeyWidget(
                        label: 'AC',
                        isAction: true,
                        onTap: onClear,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: CentsCalculatorKeyWidget(
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
      },
    );
  }

  Widget _buildDigitRow(List<String> digits) => Expanded(
    child: Row(
      spacing: _keySpacing,
      children: [
        for (final digit in digits)
          Expanded(
            child: CentsCalculatorKeyWidget(
              label: digit,
              onTap: () => onDigit(digit),
            ),
          ),
      ],
    ),
  );
}
