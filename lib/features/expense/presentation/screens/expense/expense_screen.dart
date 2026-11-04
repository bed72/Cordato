import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show ModularNavigationX;

import 'package:cordato/features/core/presentation/screens/error/error_screen.dart';
import 'package:cordato/features/core/presentation/formatters/error_message_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';

import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_state.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_suggestions_bloc.dart';

import 'package:cordato/features/expense/presentation/screens/expense/widgets/expense_form_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/expense_app_bar_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/expense_skeleton_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expense/mixins/expense_screen_state_mixin.dart';

import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_form_validator.dart';

final class const ExpenseScreen({
  super.key,
  final String? id,
  final bool returnToPrevious = false,
  required final IDateFormatter dateFormatter,
  required final IMoneyFormatter moneyFormatter,
  required final ExpenseFormValidator validator,
  required final ExpenseBloc Function() expenseBloc,
  required final ExpenseSuggestionsBloc suggestionsBloc,
}) extends StatefulWidget {
  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

final class _ExpenseScreenState extends State<ExpenseScreen>
    with ExpenseScreenStateMixin {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExpenseBloc, ExpenseState>(
      bloc: bloc,
      builder: (_, state) {
        if (state case ExpenseLoadFailure(:final errors)) {
          return ErrorScreen(
            appBar: const ExpenseAppBarWidget(),
            title: 'Não foi possível carregar a despesa.',
            description: ErrorMessageFormatter.formatAll(
              errors.errors,
              fallback: 'Tente novamente para carregar os dados.',
            ),
            actionLabel: 'Tentar novamente',
            onAction: loadExpense,
          );
        }
        final savedExpense = widget.id == null ? state.expense : null;
        return PopScope<Object?>(
          canPop: savedExpense == null,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) context.pop(savedExpense);
          },
          child: Scaffold(
            appBar: widget.id != null && state.expense?.id != widget.id
                ? const ExpenseAppBarWidget()
                : null,
            body: SafeArea(
              child: widget.id == null
                  ? _buildForm()
                  : state.expense?.id == widget.id
                  ? _buildForm(initialExpense: state.expense)
                  : _buildSkeleton(),
            ),
          ),
        );
      },
    );
  }

  ExpenseSkeletonWidget _buildSkeleton() => ExpenseSkeletonWidget(
    child: _buildForm(
      enabled: false,
      initialExpense: ExpenseEntity(
        id: widget.id!,
        category: .other,
        occurredOn: .now(),
        cents: .create(cents: 1500),
        description: 'Descrição do gasto',
      ),
    ),
  );

  ExpenseFormWidget _buildForm({
    ExpenseEntity? initialExpense,
    bool enabled = true,
  }) => ExpenseFormWidget(
    key: ValueKey((bloc, widget.id, enabled)),
    id: widget.id,
    expenseBloc: bloc,
    enabled: enabled,
    validator: widget.validator,
    initialExpense: initialExpense,
    dateFormatter: widget.dateFormatter,
    moneyFormatter: widget.moneyFormatter,
    suggestionsBloc: widget.suggestionsBloc,
    returnToPrevious: widget.returnToPrevious,
  );
}
