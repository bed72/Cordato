import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/budget/presentation/widgets/budget_form_widget.dart';
import 'package:cordato/features/budget/presentation/widgets/budget_app_bar_widget.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

final class BudgetScreen extends StatelessWidget {
  final IMoneyFormatter formatter;
  final VoidCallback onBackPressed;

  const BudgetScreen({
    super.key,
    required this.formatter,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: BudgetAppBarWidget(onBackPressed: onBackPressed),
    body: SafeArea(child: BudgetFormWidget(formatter: formatter)),
  );
}
