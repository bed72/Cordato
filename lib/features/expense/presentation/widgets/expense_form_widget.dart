import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/fields/amount_field_widget.dart';
import 'package:cordato/features/core/presentation/widgets/fields/date_field_widget.dart';
import 'package:cordato/features/expense/presentation/mixins/expense_form_widget_state_mixin.dart';
import 'package:cordato/features/expense/presentation/validators/expense_form_validator.dart';
import 'package:cordato/features/expense/presentation/widgets/expense_header_widget.dart';
import 'package:cordato/features/expense/presentation/widgets/fields/expense_description_field_widget.dart';

final class ExpenseFormWidget extends StatefulWidget {
  final IMoneyFormatter formatter;
  final ExpenseFormValidator validator;

  const ExpenseFormWidget({
    super.key,
    required this.formatter,
    required this.validator,
  });

  @override
  State<ExpenseFormWidget> createState() => _ExpenseFormWidgetState();
}

final class _ExpenseFormWidgetState extends State<ExpenseFormWidget>
    with ExpenseFormWidgetStateMixin {
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
                  onChanged: updateDescription,
                  onSubmitted: (_) => submit(),
                  controller: descriptionController,
                  failure: formState.descriptionFailure,
                ),
                AmountFieldWidget(
                  value: formState.value,
                  onTap: selectAmount,
                  formatter: widget.formatter,
                  failure: formState.valueFailure,
                ),
                DateFieldWidget(
                  label: 'Data',
                  hint: 'Data do gasto',
                  onTap: selectDate,
                  failure: formState.dateFailure,
                  value: switch (formState.date) {
                    final date? => DateTimeRange(start: date, end: date),
                    null => null,
                  },
                ),
              ],
            ),
          ),
        ),
        ElevatedButtonWidget(label: 'Cadastrar', onTap: submit),
      ],
    ),
  );
}
