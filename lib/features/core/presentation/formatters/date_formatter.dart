import 'package:intl/intl.dart';

abstract interface class IDateFormatter {
  String formatMonth(DateTime date);
  String formatLongDate(DateTime date);
  String formatShortDate(DateTime date);
  String relativeGroupHeader(DateTime date);
  String formatPeriod(DateTime start, DateTime end);
  String formatShortPeriod(DateTime start, DateTime end);
}

final class DateFormatter({DateTime Function()? now})
    implements IDateFormatter {
  static const _locale = 'pt_BR';

  final DateTime Function() _now = now ?? DateTime.now;
  final DateFormat _month = DateFormat('MMMM', _locale);
  final DateFormat _monthAbbrev = DateFormat('MMM', _locale);
  final DateFormat _shortDate = DateFormat('dd/MM/yyyy', _locale);
  final DateFormat _monthYear = DateFormat("MMMM 'de' y", _locale);

  @override
  String formatShortDate(DateTime date) => _shortDate.format(date);

  @override
  String formatMonth(DateTime date) => _capitalize(_month.format(date));

  @override
  String formatLongDate(DateTime date) => _withOptionalYear(date, _now().year);

  @override
  String formatShortPeriod(DateTime start, DateTime end) {
    final endLabel = formatShortDate(end);
    final startLabel = formatShortDate(start);

    return startLabel == endLabel ? startLabel : '$startLabel até $endLabel';
  }

  @override
  String formatPeriod(DateTime start, DateTime end) {
    final currentYear = _now().year;
    final endLabel = _withOptionalYear(end, currentYear);
    final startLabel = _withOptionalYear(start, currentYear);

    return _civilDay(start) == _civilDay(end)
        ? startLabel
        : '$startLabel até $endLabel';
  }

  @override
  String relativeGroupHeader(DateTime date) {
    final day = _civilDay(date);
    final today = _civilDay(_now());

    if (day == today) return 'Hoje';

    if (day.year != today.year ||
        day.month != today.month ||
        day.isAfter(today)) {
      return _capitalize(_monthYear.format(date));
    }

    final weekStart = today.subtract(Duration(days: today.weekday - 1));

    return day.isBefore(weekStart) ? 'Este mês' : 'Esta semana';
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
