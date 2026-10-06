import 'package:command_it/command_it.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/header_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/hold_button_widget.dart';
import 'package:cordato/features/authentication/presentation/widgets/date_field_widget.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/authentication/presentation/widgets/amount_field_widget.dart';

import 'package:cordato/features/expense/application/data/create_expense_input.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

import 'package:cordato/features/expense/presentation/validators/expense_form_validator.dart';
import 'package:cordato/features/expense/presentation/mixins/expense_form_widget_state_mixin.dart';
import 'package:cordato/features/expense/presentation/screens/expense/commands/create_expense_command.dart';
import 'package:cordato/features/expense/presentation/widgets/fields/expense_description_field_widget.dart';

final class const ExpenseFormWidget({
  super.key,
  required final IMoneyFormatter formatter,
  required final CreateExpenseCommand command,
  required final ExpenseFormValidator validator,
  required final ValueChanged<BuildContext> onExpenseCreated,
}) extends StatefulWidget {
  @override
  State<ExpenseFormWidget> createState() => _ExpenseFormWidgetState();
}

final class _ExpenseFormWidgetState extends State<ExpenseFormWidget>
    with ExpenseFormWidgetStateMixin {
  @override
  Widget build(BuildContext context) {
    return CommandBuilder<CreateExpenseInput, CreateRepositoryType?>(
      command: widget.command.execute,
      onSuccess: (_, _) => _buildContent(),
      onError: (_, _, _, _) => _buildContent(),
      whileRunning: (_, _, _) => _buildContent(isLoading: true),
    );
  }

  Padding _buildContent({bool isLoading = false}) => Padding(
    padding: const .fromLTRB(16.0, 0.0, 16.0, 24.0),
    child: Column(
      crossAxisAlignment: .stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: .onDrag,
            padding: const .symmetric(vertical: 24.0),
            child: Column(
              spacing: 16.0,
              crossAxisAlignment: .stretch,
              children: [
                const HeaderWidget(
                  title: 'Novo gasto',
                  description: 'Preencha as informações abaixo para cadastrar um novo gasto.',
                ),
                ExpenseDescriptionFieldWidget(
                  enabled: !isLoading,
                  failure: descriptionFailure,
                  onChanged: onDescriptionChanged,
                  controller: descriptionController,
                  onSubmitted: (_) => selectAmount(),
                ),
                AmountFieldWidget(
                  value: cents,
                  enabled: !isLoading,
                  failure: centsFailure,
                  formatter: widget.formatter,
                  onTap: isLoading ? null : selectAmount,
                ),
                DateFieldWidget(
                  label: 'Data',
                  enabled: !isLoading,
                  failure: dateFailure,
                  hint: 'Data do gasto',
                  onTap: isLoading ? null : selectDate,
                  value: DateTimeRange(start: occurredOn, end: occurredOn),
                ),
              ],
            ),
          ),
        ),
        HoldButtonWidget(
          label: 'Cadastrar',
          isLoading: isLoading,
          onTap: isLoading ? null : submit,
          onHoldComplete: isLoading ? null : submitAndContinue,
        ),
      ],
    ),
  );
}
