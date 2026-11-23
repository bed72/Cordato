String encodeDatabaseDate(DateTime date, {required String parameter}) {
  if (date.year < 1 || date.year > 9999) {
    throw ArgumentError.value(date, parameter);
  }

  final day = date.day.toString().padLeft(2, '0');
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');

  return '$year-$month-$day';
}
