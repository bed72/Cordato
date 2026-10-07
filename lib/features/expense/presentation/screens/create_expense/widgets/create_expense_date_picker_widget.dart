import 'package:material_ui/material_ui.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

final class const CreateExpenseDatePickerWidget({
  super.key,
  required final DateTime date,
}) extends StatefulWidget {
  @override
  State<CreateExpenseDatePickerWidget> createState() =>
      _CreateExpenseDatePickerWidgetState();
}

final class _CreateExpenseDatePickerWidgetState
    extends State<CreateExpenseDatePickerWidget> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateUtils.dateOnly(widget.date);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 424.0,
      child: Column(
        spacing: 16.0,
        children: [
          Expanded(
            child: SfDateRangePicker(
              view: .month,
              selectionMode: .single,
              showNavigationArrow: true,
              selectionShape: .rectangle,
              initialDisplayDate: _selectedDate,
              initialSelectedDate: _selectedDate,
              selectionColor: context.colors.primary,
              backgroundColor: context.colors.surface,
              todayHighlightColor: context.colors.primary,
              selectionTextStyle: context.typography.bodyMedium?.copyWith(
                color: context.colors.onPrimary,
              ),
              headerStyle: DateRangePickerHeaderStyle(
                backgroundColor: context.colors.surface,
                textStyle: context.typography.titleMedium?.copyWith(
                  fontWeight: .w600,
                  color: context.colors.onSurface,
                ),
              ),
              monthCellStyle: DateRangePickerMonthCellStyle(
                textStyle: context.typography.bodyMedium?.copyWith(
                  color: context.colors.onSurface,
                ),
                todayTextStyle: context.typography.bodyMedium?.copyWith(
                  color: context.colors.primary,
                ),
                leadingDatesTextStyle: context.typography.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant.withValues(alpha: .7),
                ),
                trailingDatesTextStyle: context.typography.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant.withValues(alpha: .7),
                ),
              ),
              monthViewSettings: DateRangePickerMonthViewSettings(
                firstDayOfWeek: 1,
                showTrailingAndLeadingDates: true,
                viewHeaderStyle: DateRangePickerViewHeaderStyle(
                  textStyle: context.typography.labelMedium?.copyWith(
                    fontWeight: .w600,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
              onSelectionChanged: _selectDate,
            ),
          ),
          SizedBox(
            width: .infinity,
            child: ElevatedButtonWidget(label: 'Selecionar', onTap: _confirm),
          ),
        ],
      ),
    );
  }

  void _selectDate(DateRangePickerSelectionChangedArgs arguments) {
    final value = arguments.value;
    if (value is! DateTime) return;

    setState(() => _selectedDate = DateUtils.dateOnly(value));
  }

  void _confirm() => Navigator.pop(context, _selectedDate);
}
