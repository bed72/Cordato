import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

extension DateTimeRangeExtension on DateTimeRange {
  String format() {
    final formatter = DateFormat('dd/MM/yyyy');
    final end = formatter.format(this.end);
    final start = formatter.format(this.start);

    return start == end ? start : '$start até $end';
  }
}
