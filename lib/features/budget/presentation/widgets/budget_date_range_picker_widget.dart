import 'package:material_ui/material_ui.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

import 'package:cordato/features/budget/presentation/mixins/budget_date_range_picker_widget_state_mixin.dart';

final class BudgetDateRangePickerWidget extends StatefulWidget {
  final DateTimeRange? range;

  const BudgetDateRangePickerWidget({super.key, this.range});

  @override
  State<BudgetDateRangePickerWidget> createState() =>
      _BudgetDateRangePickerWidgetState();
}

final class _BudgetDateRangePickerWidgetState
    extends State<BudgetDateRangePickerWidget>
    with BudgetDateRangePickerWidgetStateMixin {
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
              selectionMode: .range,
              showNavigationArrow: true,
              selectionShape: .rectangle,
              initialSelectedRange: selectedRange,
              selectionColor: context.colors.primary,
              backgroundColor: context.colors.surface,
              todayHighlightColor: context.colors.primary,
              endRangeSelectionColor: context.colors.primary,
              startRangeSelectionColor: context.colors.primary,
              initialDisplayDate: selectedRange?.startDate ?? .now(),
              rangeSelectionColor: context.colors.primary.withValues(
                alpha: .16,
              ),
              selectionTextStyle: context.typography.bodyMedium?.copyWith(
                color: context.colors.onPrimary,
              ),
              rangeTextStyle: context.typography.bodyMedium?.copyWith(
                color: context.colors.onSurface,
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
              onSelectionChanged: selectRange,
            ),
          ),
          SizedBox(
            width: .infinity,
            child: ElevatedButtonWidget(
              label: 'Selecionar',
              onTap: selectedRange == null ? null : confirm,
            ),
          ),
        ],
      ),
    );
  }
}
