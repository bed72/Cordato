import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/domain/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

import 'package:cordato/features/budget/presentation/screens/budget_screen.dart';
import 'package:cordato/features/budget/presentation/validators/budget_form_validator.dart';
import 'package:cordato/features/budget/presentation/validators/budget_value_validation.dart';
import 'package:cordato/features/budget/presentation/validators/budget_date_range_validation.dart';
import 'package:cordato/features/budget/presentation/validators/budget_description_validation.dart';

final budgetModule = createModule(
  path: RouteEnum.budget.path,
  register: (context) {
    context
      ..add(BudgetFormValidator.new)
      ..add(BudgetValueValidation.new)
      ..add(BudgetDateRangeValidation.new)
      ..add(BudgetDescriptionValidation.new)
      ..route(
        RouteEnum.root.path,
        child: (context, _) => BudgetScreen(
          onBackPressed: context.pop,
          formatter: inject<IMoneyFormatter>(),
          validator: inject<BudgetFormValidator>(),
        ),
      );
  },
);
