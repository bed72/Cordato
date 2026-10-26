import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cordato/features/core/presentation/widgets/header_widget.dart';

import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/text_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/hold_button_widget.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

import 'package:cordato/features/authentication/presentation/widgets/date_field_widget.dart';
import 'package:cordato/features/authentication/presentation/widgets/amount_field_widget.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';

import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_state.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_suggestions_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_form_validator.dart';
import 'package:cordato/features/expense/presentation/screens/expense/mixins/expense_form_widget_state_mixin.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/fields/expense_description_field_widget.dart';

final class const ExpenseFormWidget({
  super.key,
  final String? id,
  final bool enabled = true,
  final bool returnToPrevious = false,
  final ExpenseEntity? initialExpense,
  required final IDateFormatter dateFormatter,
  required final IMoneyFormatter moneyFormatter,
  required final ExpenseFormValidator validator,
  required final ExpenseBloc expenseBloc,
  required final ExpenseSuggestionsBloc suggestionsBloc,
}) extends StatefulWidget {
  @override
  State<ExpenseFormWidget> createState() => _ExpenseFormWidgetState();
}

final class _ExpenseFormWidgetState extends State<ExpenseFormWidget>
    with ExpenseFormWidgetStateMixin {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExpenseBloc, ExpenseState>(
      bloc: widget.expenseBloc,
      listener: (_, state) => handleState(state),
      builder: (_, state) => _buildContent(isLoading: state.isSubmitting),
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
                HeaderWidget(
                  title: isEditing ? 'Editar gasto' : 'Novo gasto',
                  description: isEditing
                      ? 'Atualize as informações do seu gasto.'
                      : 'Preencha as informações abaixo para cadastrar um novo gasto.',
                ),
                if (isEditing)
                  TextFieldWidget(
                    label: 'Descrição',
                    inputAction: .next,
                    hint: 'Ex: Mercado',
                    failure: descriptionFailure,
                    textCapitalization: .sentences,
                    onChanged: onDescriptionChanged,
                    controller: descriptionController,
                    onSubmitted: (_) => selectAmount(),
                    enabled: widget.enabled && !isLoading,
                  )
                else
                  ExpenseDescriptionFieldWidget(
                    failure: descriptionFailure,
                    onSelected: selectSuggestion,
                    onChanged: onDescriptionChanged,
                    hasManualAmount: hasManualAmount,
                    controller: descriptionController,
                    onSubmitted: (_) => selectAmount(),
                    enabled: widget.enabled && !isLoading,
                    moneyFormatter: widget.moneyFormatter,
                    suggestionsBloc: widget.suggestionsBloc,
                  ),
                AmountFieldWidget(
                  value: cents,
                  failure: centsFailure,
                  formatter: widget.moneyFormatter,
                  enabled: widget.enabled && !isLoading,
                  onTap: widget.enabled && !isLoading ? selectAmount : null,
                ),
                if (suggestedAmountAction case final int amount)
                  TextButtonWidget(
                    onTap: widget.enabled && !isLoading
                        ? applySuggestedAmount
                        : null,
                    child: Flexible(
                      child: Text(
                        'Usar valor sugerido: ${widget.moneyFormatter.formatCents(amount)}',
                      ),
                    ),
                  ),
                DateFieldWidget(
                  label: 'Data',
                  failure: dateFailure,
                  hint: 'Data do gasto',
                  formatter: widget.dateFormatter,
                  enabled: widget.enabled && !isLoading,
                  onTap: widget.enabled && !isLoading ? selectDate : null,
                  value: DateTimeRange(start: occurredOn, end: occurredOn),
                ),
              ],
            ),
          ),
        ),
        if (isEditing)
          ElevatedButtonWidget(
            label: 'Atualizar',
            isLoading: isLoading,
            onTap: canSubmit && !isLoading ? submit : null,
          )
        else
          HoldButtonWidget(
            label: 'Cadastrar',
            isLoading: isLoading,
            onTap: canSubmit && !isLoading ? submit : null,
            onHoldComplete: canSubmit && !isLoading ? submitAndContinue : null,
          ),
      ],
    ),
  );
}
