import 'package:material_ui/material_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';
import 'package:cordato/features/metrics/presentation/widgets/expense_metrics_grid_widget.dart';

final class const ExpenseMetricsSkeletonWidget({
  super.key,
  final bool showTotal = true,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Carregando métricas de despesas',
      child: ExcludeSemantics(
        child: Skeletonizer(
          child: Column(
            spacing: 16.0,
            crossAxisAlignment: .start,
            children: [
              if (showTotal)
                Text('R\$ 0.000,00', style: context.typography.headlineMedium),
              ExpenseMetricsGridWidget(
                moneyFormatter: MoneyFormatter(),
                categories: const [
                  ExpenseCategoryMetricsEntity(
                    percentage: 50.0,
                    totalAmount: 100000,
                    category: 'housing',
                  ),
                  ExpenseCategoryMetricsEntity(
                    category: 'food',
                    percentage: 30.0,
                    totalAmount: 60000,
                  ),
                  ExpenseCategoryMetricsEntity(
                    percentage: 20.0,
                    totalAmount: 40000,
                    category: 'transport',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
