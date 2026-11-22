import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/metrics/presentation/widgets/expense_metrics_carousel_widget.dart';

mixin ExpenseMetricsCarouselWidgetStateMixin
    on State<ExpenseMetricsCarouselWidget> {
  int currentPage = 0;
  PageController controller = PageController(keepPage: false);

  void configureViewport(double width) {
    final viewportFraction = (width - 20.0) / width;
    if (controller.viewportFraction == viewportFraction) return;

    final previousController = controller;
    controller = PageController(
      keepPage: false,
      initialPage: currentPage,
      viewportFraction: viewportFraction,
    );

    previousController.dispose();
  }

  @override
  void didUpdateWidget(covariant ExpenseMetricsCarouselWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!listEquals(
      oldWidget.pages.expand((page) => page).toList(),
      widget.pages.expand((page) => page).toList(),
    )) {
      currentPage = 0;
      if (controller.hasClients) controller.jumpToPage(0);
    }
  }

  void onPageChanged(int page) {
    if (page != currentPage) setState(() => currentPage = page);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
