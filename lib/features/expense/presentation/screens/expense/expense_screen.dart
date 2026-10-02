import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/expense/presentation/widgets/expense_form_widget.dart';
import 'package:cordato/features/expense/presentation/widgets/expense_app_bar_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expense/commands/create_expense_command.dart';
import 'package:cordato/features/expense/presentation/validators/expense_form_validator.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

final class const ExpenseScreen({
  super.key,
  required final CreateExpenseCommand command,
  required final IMoneyFormatter formatter,
  required final ExpenseFormValidator validator,
  required final VoidCallback onBackPressed,
  required final ValueChanged<BuildContext> onExpenseCreated,
}) extends StatelessWidget {
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
