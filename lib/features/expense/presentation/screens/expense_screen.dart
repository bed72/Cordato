import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/expense/presentation/widgets/expense_form_widget.dart';
import 'package:cordato/features/expense/presentation/widgets/expense_app_bar_widget.dart';
import 'package:cordato/features/expense/presentation/commands/create_expense_command.dart';
import 'package:cordato/features/expense/presentation/validators/expense_form_validator.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

final class ExpenseScreen extends StatelessWidget {
  final IMoneyFormatter formatter;
  final VoidCallback onBackPressed;
  final CreateExpenseCommand command;
  final ExpenseFormValidator validator;
  final ValueChanged<BuildContext> onExpenseCreated;

  const ExpenseScreen({
    super.key,
    required this.command,
    required this.formatter,
    required this.validator,
    required this.onBackPressed,
    required this.onExpenseCreated,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ExpenseAppBarWidget(onBackPressed: onBackPressed),
      body: SafeArea(
        child: ExpenseFormWidget(
          command: command,
          formatter: formatter,
          validator: validator,
          onExpenseCreated: onExpenseCreated,
        ),
      ),
    );
  }
}
