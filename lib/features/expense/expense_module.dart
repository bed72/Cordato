import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/expense/presentation/screens/expense_screen.dart';

final expenseModule = createModule(
  path: RouteEnum.expense.path,
  register: (context) {
    context.route(
      RouteEnum.root.path,
      child: (context, _) => ExpenseScreen(onBackPressed: context.pop),
    );
  },
);
