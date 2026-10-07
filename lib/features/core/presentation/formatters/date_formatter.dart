import 'package:intl/intl.dart';

import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';

final class DateFormatter({DateTime Function()? now})
    implements IDateFormatter {
  static const _locale = 'pt_BR';

  final DateTime Function() _now = now ?? DateTime.now;
  final DateFormat _shortDate = DateFormat('dd/MM/yyyy', _locale);
  final DateFormat _month = DateFormat('MMMM', _locale);
  final DateFormat _monthAbbrev = DateFormat('MMM', _locale);
  final DateFormat _weekday = DateFormat('EEEE', _locale);
  final DateFormat _monthYear = DateFormat('MMMM y', _locale);

  @override
  String formatShortDate(DateTime date) => _shortDate.format(date);

  @override
  String formatLongDate(DateTime date) => _withOptionalYear(date, _now().year);

  @override
  String formatMonth(DateTime date) => _capitalize(_month.format(date));

  @override
  String formatShortPeriod(DateTime start, DateTime end) {
    final startLabel = formatShortDate(start);
    final endLabel = formatShortDate(end);

    return startLabel == endLabel ? startLabel : '$startLabel até $endLabel';
  }

  @override
  String formatPeriod(DateTime start, DateTime end) {
    final currentYear = _now().year;
    final startLabel = _withOptionalYear(start, currentYear);
    final endLabel = _withOptionalYear(end, currentYear);

    return _civilDay(start) == _civilDay(end)
        ? startLabel
        : '$startLabel até $endLabel';
  }

  @override
  String relativeGroupHeader(DateTime date) {
    final days = _civilDay(_now()).difference(_civilDay(date)).inDays;

    return switch (days) {
      0 => 'Hoje',
      1 => 'Ontem',
      >= 2 && < 7 =>
        '${_capitalize(_weekday.format(date))}, ${_dayMonthLabel(date)}',
      _ => _capitalize(_monthYear.format(date)),
    };
  }

  DateTime _civilDay(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  String _dayMonthLabel(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = _capitalize(_monthAbbrev.format(date).replaceAll('.', ''));

    return '$day de $month';
  }

  String _withOptionalYear(DateTime date, int currentYear) {
    final label = _dayMonthLabel(date);

    return date.year == currentYear ? label : '$label de ${date.year}';
  }

  String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}
