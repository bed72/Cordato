import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/empty_state_widget.dart';

final class const ExpensesEmptyWidget({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const EmptyStateWidget(
    icon: Icons.receipt_long_outlined,
    title: 'Nenhum gasto neste mês',
    description: 'Seus gastos do mês aparecerão aqui...',
  );
}
