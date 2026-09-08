import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

import 'package:cordato/features/budget/presentation/mixins/budget_form_widget_state_mixin.dart';

import 'package:cordato/features/budget/presentation/widgets/budget_header_widget.dart';
import 'package:cordato/features/budget/presentation/widgets/fields/budget_date_field_widget.dart';
import 'package:cordato/features/budget/presentation/widgets/fields/budget_amount_field_widget.dart';
import 'package:cordato/features/budget/presentation/widgets/fields/budget_description_field_widget.dart';

final class BudgetFormWidget extends StatefulWidget {
  final IMoneyFormatter formatter;

  const BudgetFormWidget({super.key, required this.formatter});

  @override
  State<BudgetFormWidget> createState() => _BudgetFormWidgetState();
}

final class _BudgetFormWidgetState extends State<BudgetFormWidget>
    with BudgetFormWidgetStateMixin {
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
                const BudgetHeaderWidget(),
                BudgetAmountFieldWidget(
                  formatter: widget.formatter,
                  value: amountInCents,
                  onTap: selectAmount,
                ),
                const BudgetDateFieldWidget(),
                const BudgetDescriptionFieldWidget(),
              ],
            ),
          ),
        ),
        const ElevatedButtonWidget(label: 'Cadastrar', onTap: null),
      ],
    ),
  );
}
