import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/budget/presentation/widgets/budget_date_range_picker_widget.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/bottom_sheet_scaffold_widget.dart';

@CordatoPreview(
  group: 'Orçamentos / Widgets',
  name: 'Seletor de período',
  size: Size(390.0, 560.0),
)
Widget previewBudgetDateRangePickerWidget() => Scaffold(
  body: Align(
    alignment: .bottomCenter,
    child: BottomSheetScaffoldWidget(
      title: 'Período do orçamento',
      child: BudgetDateRangePickerWidget(
        range: DateTimeRange(
          start: DateTime(2026, 9, 1),
          end: DateTime(2026, 9, 30),
        ),
      ),
    ),
  ),
);
