import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/application/repositories/expense_repository.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';
import 'package:cordato/features/expense/infrastructure/remoto/expense_remote_data_source.dart';

import 'package:cordato/features/expense/presentation/screens/expense/expense_screen.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/expenses_screen.dart';
import 'package:cordato/features/expense/presentation/screens/expense/commands/get_expense_command.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/commands/get_expenses_command.dart';
import 'package:cordato/features/expense/presentation/screens/expense/commands/update_expense_command.dart';
import 'package:cordato/features/expense/presentation/screens/expense/commands/create_expense_command.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/commands/delete_expense_command.dart';

import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_form_validator.dart';
import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_date_validation.dart';
import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_cents_validation.dart';
import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_description_validation.dart';

final expenseDependenciesModule = createModule(
  register: (context) => context
    ..addLazySingleton<IExpenseRemoteDataSource>(ExpenseRemoteDataSource.new)
    ..addLazySingleton<IExpenseRepository>(ExpenseRepository.new)
    ..add(GetExpenseCommand.new)
    ..add(GetExpensesCommand.new)
    ..add(DeleteExpenseCommand.new)
    ..add(UpdateExpenseCommand.new)
    ..add(CreateExpenseCommand.new)
    ..add(ExpenseFormValidator.new)
    ..add(ExpenseDateValidation.new)
    ..add(ExpenseCentsValidation.new)
    ..add(ExpenseDescriptionValidation.new),
);

final expenseRoutesModule = createModule(
  path: RouteEnum.app.path,
  register: (context) {
    context
      ..route(
        RouteEnum.expenses.path,
        child: (context, state) => ExpensesScreen(
          key: ValueKey(state.arguments as ({DateTime from, DateTime to})?),
          onBackPressed: context.pop,
          getCommand: inject<GetExpensesCommand>(),
          dateFormatter: inject<IDateFormatter>(),
          moneyFormatter: inject<IMoneyFormatter>(),
          deleteCommand: inject<DeleteExpenseCommand>(),
          period: state.arguments as ({DateTime from, DateTime to})?,
          onExpensePressed: (id) => context.pushNamed<ExpenseEntity>(
            RouteEnum.expense.path,
            arguments: id,
          ),
        ),
      )
      ..route(
        RouteEnum.expense.path,
        child: (context, state) {
          final id = switch (state.arguments) {
            String id => id,
            _ => null,
          };
          final previous = switch (state.arguments) {
            (previous: final bool previous) => previous,
            _ => false,
          };

          return ExpenseScreen(
            key: ValueKey((id, previous)),
            id: id,
            onBackPressed: context.pop,
            getCommand: inject<GetExpenseCommand>(),
            dateFormatter: inject<IDateFormatter>(),
            moneyFormatter: inject<IMoneyFormatter>(),
            validator: inject<ExpenseFormValidator>(),
            createCommand: inject<CreateExpenseCommand>(),
            updateCommand: inject<UpdateExpenseCommand>(),
            onExpenseCreated: (context) => previous
                ? context.pop()
                : context.navigate(RouteEnum.dashboard.path),
            onExpenseUpdated: (context, expense) => context.pop(expense),
          );
        },
      );
  },
);
