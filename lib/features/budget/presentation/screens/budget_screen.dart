import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/budget/presentation/widgets/budget_form_widget.dart';
import 'package:cordato/features/budget/presentation/widgets/budget_app_bar_widget.dart';
import 'package:cordato/features/budget/presentation/commands/create_budget_command.dart';
import 'package:cordato/features/budget/presentation/validators/budget_form_validator.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

final class BudgetScreen extends StatelessWidget {
  final IMoneyFormatter formatter;
  final VoidCallback onBackPressed;
  final CreateBudgetCommand command;
  final BudgetFormValidator validator;
  final ValueChanged<BuildContext> onBudgetCreated;

  const BudgetScreen({
    super.key,
    required this.command,
    required this.formatter,
    required this.validator,
    required this.onBackPressed,
    required this.onBudgetCreated,
  });

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
