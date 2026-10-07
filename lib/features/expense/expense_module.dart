import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';

import 'package:cordato/features/expense/application/repositories/expense_repository.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';
import 'package:cordato/features/expense/infrastructure/remoto/expense_remote_data_source.dart';

import 'package:cordato/features/expense/presentation/screens/expenses/commands/get_expenses_command.dart';
import 'package:cordato/features/expense/presentation/screens/create_expense/create_expense_screen.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/expenses_screen.dart';

import 'package:cordato/features/expense/presentation/screens/create_expense/validators/create_expense_form_validator.dart';
import 'package:cordato/features/expense/presentation/screens/create_expense/validators/expense_date_validation.dart';
import 'package:cordato/features/expense/presentation/screens/create_expense/validators/expense_cents_validation.dart';
import 'package:cordato/features/expense/presentation/screens/create_expense/validators/expense_description_validation.dart';

import 'package:cordato/features/expense/presentation/screens/create_expense/commands/create_expense_command.dart';

final expenseDependenciesModule = createModule(
  register: (context) => context
    ..addLazySingleton<IExpenseRemoteDataSource>(ExpenseRemoteDataSource.new)
    ..addLazySingleton<IExpenseRepository>(ExpenseRepository.new)
    ..add(GetExpensesCommand.new),
);

final expenseRoutesModule = createModule(
  path: RouteEnum.app.path,
  register: (context) {
    context
      ..add(ExpenseDateValidation.new)
      ..add(ExpenseCentsValidation.new)
      ..add(CreateExpenseFormValidator.new)
      ..add(ExpenseDescriptionValidation.new)
      ..addLazySingleton<CreateExpenseCommand>(CreateExpenseCommand.new)
      ..route(
        RouteEnum.expenses.path,
        child: (context, _) => ExpensesScreen(
          command: inject<GetExpensesCommand>(),
          moneyFormatter: inject<IMoneyFormatter>(),
          dateFormatter: inject<IDateFormatter>(),
          onBackPressed: context.pop,
        ),
      )
      ..route(
        RouteEnum.expense.path,
        child: (context, _) => CreateExpenseScreen(
          onBackPressed: context.pop,
          command: inject<CreateExpenseCommand>(),
          dateFormatter: inject<IDateFormatter>(),
          moneyFormatter: inject<IMoneyFormatter>(),
          validator: inject<CreateExpenseFormValidator>(),
          onExpenseCreated: (context) =>
              context.navigate(RouteEnum.dashboard.path),
        ),
      );
  },
);
