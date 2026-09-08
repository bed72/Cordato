import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';
import 'package:cordato/features/expense/presentation/widgets/expense_header_widget.dart';
import 'package:cordato/features/expense/presentation/widgets/fields/expense_amount_field_widget.dart';
import 'package:cordato/features/expense/presentation/widgets/fields/expense_date_field_widget.dart';
import 'package:cordato/features/expense/presentation/widgets/fields/expense_description_field_widget.dart';

final class ExpenseFormWidget extends StatelessWidget {
  const ExpenseFormWidget({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 24.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              spacing: 16.0,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExpenseHeaderWidget(),
                ExpenseDescriptionFieldWidget(),
                ExpenseAmountFieldWidget(),
                ExpenseDateFieldWidget(),
              ],
            ),
          ),
        ),
        ElevatedButtonWidget(label: 'Cadastrar', onTap: _register),
      ],
    ),
  );

  static void _register() {}
}
