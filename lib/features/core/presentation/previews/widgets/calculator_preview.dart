import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/core/presentation/widgets/calculator/amount_calculator_widget.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/bottom_sheet_scaffold_widget.dart';

@CordatoPreview(
  group: 'Core / Calculadora',
  name: 'Valor',
  size: Size(390.0, 620.0),
)
Widget previewAmountCalculatorWidget() => Scaffold(
  body: Align(
    alignment: .bottomCenter,
    child: BottomSheetScaffoldWidget(
      title: 'Informe o valor',
      child: AmountCalculatorWidget(value: 259990, formatter: MoneyFormatter()),
    ),
  ),
);
