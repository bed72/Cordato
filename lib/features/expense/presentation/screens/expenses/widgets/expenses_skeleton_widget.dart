import 'package:material_ui/material_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expense_item_widget.dart';

final class const ExpensesSkeletonWidget({super.key, required final int count})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Skeletonizer(
        child: Column(
          mainAxisSize: .min,
          children: .generate(
            count,
            (_) => const ExpenseItemWidget(
              category: .other,
              formattedDate: '00 de mmm',
              formattedValue: 'R\$ 000,00',
              description: 'Carregando descrição da despesa',
            ),
          ),
        ),
      ),
    );
  }
}
