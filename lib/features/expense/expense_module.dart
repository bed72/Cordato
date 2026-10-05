import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

import 'package:cordato/features/expense/presentation/screens/expense/expense_screen.dart';
import 'package:cordato/features/expense/presentation/validators/expense_date_validation.dart';
import 'package:cordato/features/expense/presentation/validators/expense_form_validator.dart';
import 'package:cordato/features/expense/presentation/validators/expense_description_validation.dart';

final expenseModule = createModule(
  path: RouteEnum.expense.path,
  register: (context) {
    context
      ..add(ExpenseFormValidator.new)
      ..add(ExpenseDateValidation.new)
      ..add(ExpenseDescriptionValidation.new)
      ..route(
        RouteEnum.root.path,
        child: (context, _) => ExpenseScreen(
          onBackPressed: context.pop,
          formatter: inject<IMoneyFormatter>(),
          validator: inject<ExpenseFormValidator>(),
          onExpenseCreated: (context) =>
              context.navigate(RouteEnum.dashboard.path),
        ),
      );
  },
);
