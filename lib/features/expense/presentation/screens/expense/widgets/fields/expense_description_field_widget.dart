import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/core/presentation/widgets/fields/autocomplete_text_field_widget.dart';

import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';

import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_suggestions_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_suggestions_state.dart';
import 'package:cordato/features/expense/presentation/screens/expense/mixins/expense_description_field_state_mixin.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/expense_suggestions_widget.dart';

final class const ExpenseDescriptionFieldWidget({
  super.key,
  required final IMoneyFormatter moneyFormatter,
  required final TextEditingController controller,
  required final ExpenseSuggestionsBloc suggestionsBloc,
  required final ValueChanged<ExpenseSuggestionEntity> onSelected,
  final String? failure,
  final bool enabled = true,
  final bool hasManualAmount = false,
  final ValueChanged<String>? onChanged,
  final ValueChanged<String>? onSubmitted,
}) extends StatefulWidget {
  @override
  State<ExpenseDescriptionFieldWidget> createState() =>
      _ExpenseDescriptionFieldState();
}

final class _ExpenseDescriptionFieldState
    extends State<ExpenseDescriptionFieldWidget>
    with ExpenseDescriptionFieldStateMixin {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AutocompleteTextFieldWidget<ExpenseSuggestionEntity>(
        inputAction: .next,
        label: 'Descrição',
        hint: 'Ex: Mercado',
        optionsBuilder: lookup,
        failure: widget.failure,
        enabled: widget.enabled,
        onInvalidated: invalidate,
        onChanged: widget.onChanged,
        controller: widget.controller,
        onSelected: widget.onSelected,
        textCapitalization: .sentences,
        onSubmitted: widget.onSubmitted,
        displayStringForOption: (option) => option.description,
        optionsViewBuilder: (context, select, options) =>
            ExpenseSuggestionsWidget(
              onSelected: select,
              suggestions: options.toList(),
              moneyFormatter: widget.moneyFormatter,
              hasManualAmount: widget.hasManualAmount,
            ),
      ),
      BlocBuilder<ExpenseSuggestionsBloc, ExpenseSuggestionsState>(
        bloc: widget.suggestionsBloc,
        builder: (context, state) =>
            state is ExpenseSuggestionsLoading && widget.enabled
            ? Semantics(
                liveRegion: true,
                label: 'Buscando sugestões',
                child: const Padding(
                  padding: .only(top: 2, left: 8, right: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              )
            : const SizedBox.shrink(),
      ),
    ],
  );
}
