import 'package:flutter_modular/flutter_modular.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

import 'package:cordato/features/budget/data/repositories/budget_repository.dart';
import 'package:cordato/features/budget/infrastructure/remoto/budget_data_source.dart';
import 'package:cordato/features/budget/infrastructure/clients/supabase_budget_client.dart';
import 'package:cordato/features/budget/domain/repositories/interface_budget_repository.dart';

import 'package:cordato/features/budget/presentation/screens/budget_screen.dart';
import 'package:cordato/features/budget/presentation/commands/create_budget_command.dart';
import 'package:cordato/features/budget/presentation/validators/budget_form_validator.dart';
import 'package:cordato/features/budget/presentation/validators/budget_value_validation.dart';
import 'package:cordato/features/budget/presentation/validators/budget_date_range_validation.dart';

final budgetModule = createModule(
  path: RouteEnum.budget.path,
  register: (context) {
    context
      ..add(BudgetFormValidator.new)
      ..add(BudgetValueValidation.new)
      ..add(BudgetDateRangeValidation.new)
      ..addLazySingleton<IBudgetDataSource>(BudgetDataSource.new)
      ..addLazySingleton<IBudgetRepository>(BudgetRepository.new)
      ..addLazySingleton<CreateBudgetCommand>(CreateBudgetCommand.new)
      ..addLazySingleton<IBudgetClient>(
        () => SupabaseBudgetClient(client: Supabase.instance.client),
      )
      ..route(
        RouteEnum.root.path,
        child: (context, _) => BudgetScreen(
          onBackPressed: context.pop,
          formatter: inject<IMoneyFormatter>(),
          command: inject<CreateBudgetCommand>(),
          validator: inject<BudgetFormValidator>(),
          onBudgetCreated: (context) =>
              context.navigate(RouteEnum.dashboard.path),
        ),
      );
  },
);
