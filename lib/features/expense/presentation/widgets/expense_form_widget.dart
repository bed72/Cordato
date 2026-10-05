import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/fields/date_field_widget.dart';
import 'package:cordato/features/core/presentation/widgets/fields/amount_field_widget.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

import 'package:cordato/features/expense/presentation/widgets/expense_header_widget.dart';
import 'package:cordato/features/expense/presentation/validators/expense_form_validator.dart';
import 'package:cordato/features/expense/presentation/widgets/fields/expense_description_field_widget.dart';

final class const ExpenseFormWidget({
  super.key,
  required final IMoneyFormatter formatter,
  required final ExpenseFormValidator validator,
  required final ValueChanged<BuildContext> onExpenseCreated,
}) extends StatefulWidget {
  @override
  State<ExpenseFormWidget> createState() => _ExpenseFormWidgetState();
}

final class _ExpenseFormWidgetState extends State<ExpenseFormWidget> {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const .fromLTRB(16.0, 0.0, 16.0, 24.0),
    child: Column(
      crossAxisAlignment: .stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const .symmetric(vertical: 24.0),
            child: Column(
              spacing: 16.0,
              crossAxisAlignment: .stretch,
              children: [
                const ExpenseHeaderWidget(),
                ExpenseDescriptionFieldWidget(
                  onChanged: (_) {},
                  onSubmitted: (_) {},
                  controller: TextEditingController(),
                  failure: '',
                ),
                AmountFieldWidget(
                  value: 0,
                  onTap: () {},
                  formatter: widget.formatter,
                  failure: '',
                ),
                DateFieldWidget(
                  label: 'Data',
                  onTap: () {},
                  hint: 'Data do gasto',
                  failure: '',
                  value: DateTimeRange(start: .now(), end: .now()),
                ),
              ],
            ),
          ),
        ),
        const ElevatedButtonWidget(
          onTap: null,
          isLoading: true,
          label: 'Cadastrar',
        ),
      ],
    ),
  );
}
