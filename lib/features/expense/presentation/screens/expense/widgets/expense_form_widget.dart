import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show ModularNavigationX;

import 'package:cordato/features/core/presentation/widgets/header_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/back_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/headers/collapsible_header_widget.dart';

import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';
import 'package:cordato/features/core/presentation/widgets/fields/amount_field_widget.dart';
import 'package:cordato/features/core/presentation/widgets/fields/date_field_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/text_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/hold_button_widget.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';

import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_state.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_suggestions_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_form_validator.dart';
import 'package:cordato/features/expense/presentation/screens/expense/mixins/expense_form_widget_state_mixin.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/fields/expense_category_field_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/fields/expense_description_field_widget.dart';

final class const ExpenseFormWidget({
  super.key,
  final String? id,
  final bool enabled = true,
  final bool returnToPrevious = false,
  final ExpenseEntity? initialExpense,
  required final ExpenseBloc expenseBloc,
  required final IDateFormatter dateFormatter,
  required final IMoneyFormatter moneyFormatter,
  required final ExpenseFormValidator validator,
  required final ExpenseSuggestionsBloc suggestionsBloc,
}) extends StatefulWidget {
  @override
  State<ExpenseFormWidget> createState() => _ExpenseFormWidgetState();
}

final class _ExpenseFormWidgetState extends State<ExpenseFormWidget>
    with ExpenseFormWidgetStateMixin {
  String get _title => isEditing ? 'Editar gasto' : 'Novo gasto';

  String get _description => isEditing
      ? 'Atualize as informações do seu gasto.'
      : 'Preencha as informações abaixo para cadastrar um novo gasto.';

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExpenseBloc, ExpenseState>(
      bloc: widget.expenseBloc,
      listener: (_, state) => handleState(state),
      builder: (_, state) => _buildContent(
        isLoading: state.isSubmitting,
        createdExpense: isEditing ? null : state.expense,
      ),
    );
  }

  Padding _buildContent({
    bool isLoading = false,
    ExpenseEntity? createdExpense,
  }) => Padding(
    padding: const .only(bottom: 16.0),
    child: Column(
      crossAxisAlignment: .stretch,
      children: [
        Expanded(
          child: CustomScrollView(
            keyboardDismissBehavior: .onDrag,
            slivers: [
              if (widget.enabled)
                CollapsibleHeaderWidget(
                  title: _title,
                  description: _description,
                  leading: BackButtonWidget(
                    onPress: () => context.pop(createdExpense),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const .all(16.0),
                    child: HeaderWidget(
                      title: _title,
                      description: _description,
                    ),
                  ),
                ),
              SliverPadding(
                padding: const .fromLTRB(16.0, 0.0, 16.0, 24.0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    spacing: 16.0,
                    crossAxisAlignment: .stretch,
                    children: [
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
                        onTap: widget.enabled && !isLoading
                            ? selectAmount
                            : null,
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
                      ExpenseCategoryFieldWidget(
                        value: category,
                        enabled: widget.enabled && !isLoading,
                        onTap: widget.enabled && !isLoading
                            ? selectCategory
                            : null,
                      ),
                      DateFieldWidget(
                        label: 'Data',
                        failure: dateFailure,
                        hint: 'Data do gasto',
                        formatter: widget.dateFormatter,
                        enabled: widget.enabled && !isLoading,
                        onTap: widget.enabled && !isLoading ? selectDate : null,
                        value: DateTimeRange(
                          end: occurredOn,
                          start: occurredOn,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const .symmetric(horizontal: 16.0),
          child: isEditing
              ? ElevatedButtonWidget(
                  label: 'Atualizar',
                  isLoading: isLoading,
                  onTap: canSubmit && !isLoading ? submit : null,
                )
              : HoldButtonWidget(
                  label: 'Cadastrar',
                  isLoading: isLoading,
                  onTap: canSubmit && !isLoading ? submit : null,
                  onHoldComplete: canSubmit && !isLoading
                      ? submitAndContinue
                      : null,
                ),
        ),
      ],
    ),
  );
}
