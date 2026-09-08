import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/expense/presentation/validators/expense_form_validator.dart';
import 'package:cordato/features/expense/presentation/widgets/expense_app_bar_widget.dart';
import 'package:cordato/features/expense/presentation/widgets/expense_form_widget.dart';

final class ExpenseScreen extends StatelessWidget {
  final IMoneyFormatter formatter;
  final ExpenseFormValidator validator;
  final VoidCallback onBackPressed;

  const ExpenseScreen({
    super.key,
    required this.formatter,
    required this.validator,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ExpenseAppBarWidget(onBackPressed: onBackPressed),
      body: SafeArea(
        child: ExpenseFormWidget(formatter: formatter, validator: validator),
      ),
    );
  }
}
