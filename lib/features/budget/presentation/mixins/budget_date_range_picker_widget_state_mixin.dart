import 'package:material_ui/material_ui.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import 'package:cordato/features/budget/presentation/widgets/budget_date_range_picker_widget.dart';

mixin BudgetDateRangePickerWidgetStateMixin
    on State<BudgetDateRangePickerWidget> {
  PickerDateRange? selectedRange;

  bool get hasCompleteRange {
    final start = selectedRange?.startDate;
    final end = selectedRange?.endDate;

    return start != null && end != null && end.isAfter(start);
  }

  @override
  void initState() {
    super.initState();
    final range = widget.range;
    if (range == null) return;

    selectedRange = PickerDateRange(range.start, range.end);
  }

  void selectRange(DateRangePickerSelectionChangedArgs arguments) {
    final value = arguments.value;
    if (value is! PickerDateRange) return;

    setState(() => selectedRange = value);
  }

  void confirm() {
    final start = selectedRange?.startDate;
    final end = selectedRange?.endDate;
    if (start == null || end == null || !end.isAfter(start)) return;

    Navigator.pop(
      context,
      DateTimeRange(
        end: DateUtils.dateOnly(end),
        start: DateUtils.dateOnly(start),
      ),
    );
  }
}
