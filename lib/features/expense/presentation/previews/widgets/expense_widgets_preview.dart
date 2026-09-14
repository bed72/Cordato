import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/expense/presentation/widgets/expense_date_picker_widget.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/bottom_sheet_scaffold_widget.dart';

@CordatoPreview(
  group: 'Gastos / Widgets',
  name: 'Seletor de data',
  size: Size(390.0, 560.0),
)
Widget previewExpenseDatePickerWidget() => Scaffold(
  body: Align(
    alignment: .bottomCenter,
    child: BottomSheetScaffoldWidget(
      title: 'Data do gasto',
      child: ExpenseDatePickerWidget(date: DateTime(2026, 9, 13)),
    ),
  ),
);
