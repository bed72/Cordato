import 'package:command_it/command_it.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/fields/amount_field_widget.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

import 'package:cordato/features/budget/domain/entities/budget_entity.dart';
import 'package:cordato/features/budget/presentation/widgets/budget_header_widget.dart';
import 'package:cordato/features/budget/presentation/commands/create_budget_command.dart';
import 'package:cordato/features/budget/presentation/validators/budget_form_validator.dart';
import 'package:cordato/features/budget/presentation/mixins/budget_form_widget_state_mixin.dart';
import 'package:cordato/features/budget/presentation/widgets/budget_period_selector_widget.dart';
import 'package:cordato/features/budget/presentation/widgets/budget_recurrence_field_widget.dart';

final class const BudgetFormWidget({
  super.key,
  required final CreateBudgetCommand command,
  required final IMoneyFormatter formatter,
  required final BudgetFormValidator validator,
  required final ValueChanged<BuildContext> onBudgetCreated,
}) extends StatefulWidget {
  @override
  State<BudgetFormWidget> createState() => _BudgetFormWidgetState();
}

final class _BudgetFormWidgetState extends State<BudgetFormWidget>
    with BudgetFormWidgetStateMixin {
  @override
  Widget build(BuildContext context) {
    return Padding(
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
                  AmountFieldWidget(
                    onTap: selectAmount,
                    value: form.value,
                    failure: form.valueFailure,
                    formatter: widget.formatter,
                  ),
                  BudgetPeriodSelectorWidget(
                    period: form.period,
                    onSelected: selectPeriod,
                    failure: form.periodFailure,
                    selectedOption: form.periodOption,
                  ),
                  BudgetRecurrenceFieldWidget(
                    value: form.isRecurring,
                    onChanged: updateRecurrence,
                  ),
                ],
              ),
            ),
          ),
          CommandBuilder<BudgetEntity, void>(
            command: widget.command.create,
            whileRunning: (_, _, _) => const ElevatedButtonWidget(
              onTap: null,
              isLoading: true,
              label: 'Cadastrar',
            ),
            onSuccess: (_, _) =>
                ElevatedButtonWidget(label: 'Cadastrar', onTap: submit),
            onError: (_, _, _, _) =>
                ElevatedButtonWidget(label: 'Cadastrar', onTap: submit),
          ),
        ],
      ),
    );
  }
}
