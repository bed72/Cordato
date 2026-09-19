import 'package:material_ui/material_ui.dart';

enum BudgetPeriodOptionEnum(final String label) {
  weekly('Semanal'),
  monthly('Mensal'),
  custom('Personalizado');

  DateTimeRange? periodStartingAt(DateTime value) {
    final start = DateUtils.dateOnly(value);

    return switch (this) {
      weekly => DateTimeRange(
        start: start,
        end: start.add(const Duration(days: 6)),
      ),
      monthly => DateTimeRange(end: _monthlyEnd(start), start: start),
      custom => null,
    };
  }

  static DateTime _monthlyEnd(DateTime start) {
    final nextMonth = start.month == DateTime.december ? 1 : start.month + 1;
    final nextYear = start.month == DateTime.december
        ? start.year + 1
        : start.year;
    if (start.day == 1) {
      return DateTime(nextYear, nextMonth).subtract(const Duration(days: 1));
    }

    final lastDay = DateUtils.getDaysInMonth(nextYear, nextMonth);
    final endDay = start.day - 1 > lastDay ? lastDay : start.day - 1;

    return DateTime(nextYear, nextMonth, endDay);
  }
}
