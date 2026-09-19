import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/budget/presentation/widgets/budget_period_selector_widget.dart';

mixin BudgetPeriodSelectorWidgetStateMixin
    on State<BudgetPeriodSelectorWidget> {
  static const _monthAbbreviations = <String>[
    'Jan.',
    'Fev.',
    'Mar.',
    'Abr.',
    'Mai.',
    'Jun.',
    'Jul.',
    'Ago.',
    'Set.',
    'Out.',
    'Nov.',
    'Dez.',
  ];

  String formatPeriod(DateTimeRange value) {
    final showYear = value.start.year != value.end.year;
    final end = _formatDate(value.end, showYear: showYear);
    final start = _formatDate(value.start, showYear: showYear);

    return '$start até $end';
  }

  String _formatDate(DateTime value, {required bool showYear}) {
    final month = _monthAbbreviations[value.month - 1];
    final date = '${value.day} de $month';

    return showYear ? '$date de ${value.year}' : date;
  }
}
