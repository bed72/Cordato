import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/budget/presentation/widgets/budget_form_widget.dart';
import 'package:cordato/features/budget/presentation/widgets/budget_app_bar_widget.dart';
import 'package:cordato/features/budget/presentation/commands/create_budget_command.dart';
import 'package:cordato/features/budget/presentation/validators/budget_form_validator.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

final class const BudgetScreen({
  super.key,
  required final CreateBudgetCommand command,
  required final IMoneyFormatter formatter,
  required final BudgetFormValidator validator,
  required final VoidCallback onBackPressed,
  required final ValueChanged<BuildContext> onBudgetCreated,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: BudgetAppBarWidget(onBackPressed: onBackPressed),
    body: SafeArea(
      child: BudgetFormWidget(
        command: command,
        formatter: formatter,
        validator: validator,
        onBudgetCreated: onBudgetCreated,
      ),
    ),
  );
}
