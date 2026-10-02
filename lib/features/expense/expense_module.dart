import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

import 'package:cordato/features/expense/data/repositories/expense_repository.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

import 'package:cordato/features/expense/infrastructure/remoto/expense_data_source.dart';
import 'package:cordato/features/expense/infrastructure/clients/expense_client.dart';

import 'package:cordato/features/expense/presentation/screens/expense/expense_screen.dart';
import 'package:cordato/features/expense/presentation/screens/expense/commands/create_expense_command.dart';
import 'package:cordato/features/expense/presentation/validators/expense_date_validation.dart';
import 'package:cordato/features/expense/presentation/validators/expense_form_validator.dart';
import 'package:cordato/features/expense/presentation/validators/expense_value_validation.dart';
import 'package:cordato/features/expense/presentation/validators/expense_description_validation.dart';

final expenseModule = createModule(
  path: RouteEnum.expense.path,
  register: (context) {
    context
      ..add(ExpenseFormValidator.new)
      ..add(ExpenseDateValidation.new)
      ..add(ExpenseValueValidation.new)
      ..add(ExpenseDescriptionValidation.new)
      ..addLazySingleton<IExpenseDataSource>(ExpenseDataSource.new)
      ..addLazySingleton<IExpenseRepository>(ExpenseRepository.new)
      ..addLazySingleton<CreateExpenseCommand>(CreateExpenseCommand.new)
      ..addLazySingleton<IExpenseClient>(() => ExpenseClient())
      ..route(
        RouteEnum.root.path,
        child: (context, _) => ExpenseScreen(
          onBackPressed: context.pop,
          formatter: inject<IMoneyFormatter>(),
          command: inject<CreateExpenseCommand>(),
          validator: inject<ExpenseFormValidator>(),
          onExpenseCreated: (context) =>
              context.navigate(RouteEnum.dashboard.path),
        ),
      );
  },
);
