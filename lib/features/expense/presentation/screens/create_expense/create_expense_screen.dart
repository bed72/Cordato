import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

import 'package:cordato/features/expense/presentation/widgets/create_expense_form_widget.dart';
import 'package:cordato/features/expense/presentation/widgets/create_expense_app_bar_widget.dart';
import 'package:cordato/features/expense/presentation/validators/create_expense_form_validator.dart';
import 'package:cordato/features/expense/presentation/screens/create_expense/commands/create_expense_command.dart';

final class const CreateExpenseScreen({
  super.key,
  required final VoidCallback onBackPressed,
  required final CreateExpenseCommand command,
  required final IDateFormatter dateFormatter,
  required final IMoneyFormatter moneyFormatter,
  required final CreateExpenseFormValidator validator,
  required final ValueChanged<BuildContext> onExpenseCreated,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CreateExpenseAppBarWidget(onBackPressed: onBackPressed),
      body: SafeArea(
        child: CreateExpenseFormWidget(
          command: command,
          validator: validator,
          formatter: moneyFormatter,
          dateFormatter: dateFormatter,
          onExpenseCreated: onExpenseCreated,
        ),
      ),
    );
  }
}
