abstract interface class IDateFormatter {
  String formatMonth(DateTime date);

  String formatLongDate(DateTime date);

  String formatShortDate(DateTime date);

  String formatPeriod(DateTime start, DateTime end);

  String formatShortPeriod(DateTime start, DateTime end);

  String relativeGroupHeader(DateTime date);
}
