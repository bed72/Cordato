import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/extensions/bloc_scoped_extension.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

import 'package:cordato/features/expense/infrastructure/repositories/expense_repository.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_repository.dart';

import 'package:cordato/features/expense/presentation/screens/expense/expense_screen.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/expenses_screen.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_suggestions_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_form_validator.dart';
import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_date_validation.dart';
import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_cents_validation.dart';
import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_description_validation.dart';

final expenseModule = createModule(
  register: (context) {
    context
      ..addLazySingleton<IExpenseRepository>(ExpenseRepository.new)
      ..add(ExpenseBloc.new)
      ..add(ExpensesBloc.new)
      ..add(ExpenseFormValidator.new)
      ..add(ExpenseDateValidation.new)
      ..add(ExpenseCentsValidation.new)
      ..add(ExpenseDescriptionValidation.new)
      ..route(
        RouteEnum.expenses.path,
        child: (context, state) {
          final period = switch (state.arguments) {
            (
              to: final DateTime to,
              from: final DateTime from,
              category: final String? _,
            ) =>
              (from: from, to: to),
            (from: final DateTime from, to: final DateTime to) => (
              to: to,
              from: from,
            ),
            _ => null,
          };
          final category = switch (state.arguments) {
            (
              to: final DateTime _,
              from: final DateTime _,
              category: final String? category,
            ) =>
              category,
            _ => null,
          };

          return ExpensesScreen(
            key: ValueKey((period, category)),
            period: period,
            category: category,
            bloc: inject<ExpensesBloc>,
            dateFormatter: inject<IDateFormatter>(),
            moneyFormatter: inject<IMoneyFormatter>(),
          );
        },
      )
      ..route(
        RouteEnum.expense.path,
        provide: (scope) =>
            scope.addBloc<ExpenseSuggestionsBloc>(ExpenseSuggestionsBloc.new),
        child: (context, state) {
          final id = switch (state.arguments) {
            String id => id,
            _ => null,
          };

          final previous = switch (state.arguments) {
            (returnToPrevious: final bool previous) => previous,
            _ => false,
          };

          return ExpenseScreen(
            key: ValueKey((id, previous)),
            id: id,
            returnToPrevious: previous,
            expenseBloc: inject<ExpenseBloc>,
            dateFormatter: inject<IDateFormatter>(),
            moneyFormatter: inject<IMoneyFormatter>(),
            validator: inject<ExpenseFormValidator>(),
            suggestionsBloc: context.read<ExpenseSuggestionsBloc>(),
          );
        },
      );
  },
);
