import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';

import 'package:cordato/features/expense/data/repositories/expense_repository.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';
import 'package:cordato/features/expense/infrastructure/remoto/expense_remote_data_source.dart';

import 'package:cordato/features/expense/presentation/commands/get_expenses_command.dart';
import 'package:cordato/features/expense/presentation/screens/create_expense/create_expense_screen.dart';

import 'package:cordato/features/expense/presentation/validators/create_expense_form_validator.dart';
import 'package:cordato/features/expense/presentation/validators/expense_date_validation.dart';
import 'package:cordato/features/expense/presentation/validators/expense_cents_validation.dart';
import 'package:cordato/features/expense/presentation/validators/expense_description_validation.dart';

import 'package:cordato/features/expense/presentation/screens/create_expense/commands/create_expense_command.dart';

final expenseDependenciesModule = createModule(
  register: (context) => context
    ..addLazySingleton<IExpenseRemoteDataSource>(ExpenseRemoteDataSource.new)
    ..addLazySingleton<IExpenseRepository>(ExpenseRepository.new)
    ..add(GetExpensesCommand.new),
);

final expenseRoutesModule = createModule(
  path: RouteEnum.expense.path,
  register: (context) {
    context
      ..add(CreateExpenseFormValidator.new)
      ..add(ExpenseDateValidation.new)
      ..add(ExpenseCentsValidation.new)
      ..add(ExpenseDescriptionValidation.new)
      ..addLazySingleton<CreateExpenseCommand>(CreateExpenseCommand.new)
      ..route(
        RouteEnum.app.path,
        child: (context, _) => CreateExpenseScreen(
          onBackPressed: context.pop,
          moneyFormatter: inject<IMoneyFormatter>(),
          dateFormatter: inject<IDateFormatter>(),
          command: inject<CreateExpenseCommand>(),
          validator: inject<CreateExpenseFormValidator>(),
          onExpenseCreated: (context) =>
              context.navigate(RouteEnum.dashboard.path),
        ),
      );
  },
);
