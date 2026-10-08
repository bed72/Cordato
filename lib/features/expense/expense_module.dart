import 'package:flutter_modular/flutter_modular.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';

import 'package:cordato/features/expense/application/repositories/expense_repository.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/infrastructure/remoto/expense_remote_data_source.dart';

import 'package:cordato/features/expense/presentation/screens/expenses/commands/get_expenses_command.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/commands/delete_expense_command.dart';
import 'package:cordato/features/expense/presentation/screens/expense/commands/update_expense_command.dart';
import 'package:cordato/features/expense/presentation/screens/expense/commands/get_expense_command.dart';
import 'package:cordato/features/expense/presentation/screens/expense/expense_screen.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/expenses_screen.dart';

import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_form_validator.dart';
import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_date_validation.dart';
import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_cents_validation.dart';
import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_description_validation.dart';

import 'package:cordato/features/expense/presentation/screens/expense/commands/create_expense_command.dart';

final expenseDependenciesModule = createModule(
  register: (context) => context
    ..addLazySingleton<IExpenseRemoteDataSource>(ExpenseRemoteDataSource.new)
    ..addLazySingleton<IExpenseRepository>(ExpenseRepository.new)
    ..add(GetExpensesCommand.new)
    ..add(DeleteExpenseCommand.new)
    ..add(UpdateExpenseCommand.new)
    ..add(GetExpenseCommand.new)
    ..add(CreateExpenseCommand.new)
    ..add(ExpenseDateValidation.new)
    ..add(ExpenseCentsValidation.new)
    ..add(ExpenseFormValidator.new)
    ..add(ExpenseDescriptionValidation.new),
);

final expenseRoutesModule = createModule(
  path: RouteEnum.app.path,
  register: (context) {
    context
      ..route(
        RouteEnum.expenses.path,
        child: (context, _) => ExpensesScreen(
          onBackPressed: context.pop,
          command: inject<GetExpensesCommand>(),
          dateFormatter: inject<IDateFormatter>(),
          moneyFormatter: inject<IMoneyFormatter>(),
          deleteCommand: inject<DeleteExpenseCommand>(),
          onExpensePressed: (id) => context.pushNamed<ExpenseEntity>(
            RouteEnum.expense.path,
            arguments: id,
          ),
        ),
      )
      ..route(
        RouteEnum.expense.path,
        child: (context, state) => ExpenseScreen(
          key: ValueKey(state.arguments as String?),
          id: state.arguments as String?,
          onBackPressed: context.pop,
          createCommand: inject<CreateExpenseCommand>(),
          getCommand: inject<GetExpenseCommand>(),
          updateCommand: inject<UpdateExpenseCommand>(),
          dateFormatter: inject<IDateFormatter>(),
          moneyFormatter: inject<IMoneyFormatter>(),
          validator: inject<ExpenseFormValidator>(),
          onExpenseCreated: (context) =>
              context.navigate(RouteEnum.dashboard.path),
          onExpenseUpdated: (context, expense) => context.pop(expense),
        ),
      );
  },
);
