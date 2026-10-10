import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';
import 'package:cordato/features/metrics/presentation/widgets/expense_metrics_chart_widget.dart';
import 'package:cordato/features/metrics/presentation/extensions/expense_category_metrics_extension.dart';

mixin ExpenseMetricsChartWidgetStateMixin on State<ExpenseMetricsChartWidget> {
  int selectedIndex = 0;

  int get chartTotal => widget.categories.fold<int>(
    0,
    (amount, category) => amount + category.totalAmount,
  );

  ExpenseCategoryMetricsEntity get selectedCategory =>
      widget.categories[selectedIndex];

  Color get selectedCategoryColor => selectedCategory.color(context);

  String get selectedCategoryLabel => selectedCategory.label;

  String get selectedCategoryAmount =>
      '${widget.moneyFormatter.formatCents(selectedCategory.totalAmount)} · '
      '${_percentage(selectedCategory.percentage, 2)} do total';

  String get selectedCategoryDetails =>
      '$selectedCategoryLabel · $selectedCategoryAmount';

  @override
  void initState() {
    super.initState();
    selectedIndex = _largestCategoryIndex();
  }

  @override
  void didUpdateWidget(covariant ExpenseMetricsChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categories != widget.categories) {
      selectedIndex = _largestCategoryIndex();
    }
  }

  void onChartTouch(FlTouchEvent event, BarTouchResponse? response) {
    if (event is! FlTapUpEvent || response?.spot == null) {
      return;
    }
    final index = response!.spot!.touchedStackItemIndex;
    if (index >= 0 && index < widget.categories.length) {
      _select(index);
    }
  }

  List<BarChartRodStackItem> get chartSegments {
    final total = chartTotal;
    if (total <= 0) return [];

    int offset = 0;
    final segments = <BarChartRodStackItem>[];

    for (final (index, category) in widget.categories.indexed) {
      final next = offset + category.totalAmount;
      final color = category.color(context);
      final displayedColor = selectedIndex == index
          ? color
          : color.withValues(alpha: 0.55);
      segments.add(
        BarChartRodStackItem(
          offset.toDouble(),
          next.toDouble(),
          displayedColor,
          borderSide: BorderSide(color: context.colors.surface, width: 1.0),
        ),
      );
      offset = next;
    }
    return segments;
  }

  void _select(int index) => setState(() => selectedIndex = index);

  int _largestCategoryIndex() {
    int largest = 0;
    for (int index = 1; index < widget.categories.length; index++) {
      if (widget.categories[index].totalAmount >
          widget.categories[largest].totalAmount) {
        largest = index;
      }
    }
    return largest;
  }

  String _percentage(double percentage, int decimalDigits) =>
      '${NumberFormat.decimalPatternDigits(locale: 'pt_BR', decimalDigits: decimalDigits).format(percentage)}%';
}
