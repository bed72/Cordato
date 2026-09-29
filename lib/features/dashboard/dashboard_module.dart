import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';

import 'package:cordato/features/dashboard/data/repositories/user_repository.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:cordato/features/dashboard/infrastructure/remoto/user_data_source.dart';
import 'package:cordato/features/dashboard/presentation/commands/get_user_name_command.dart';
import 'package:cordato/features/dashboard/infrastructure/clients/user_client.dart';
import 'package:cordato/features/dashboard/domain/repositories/interface_user_repository.dart';

final dashboardModule = createModule(
  path: RouteEnum.dashboard.path,
  register: (context) {
    context
      ..addLazySingleton<IUserDataSource>(UserDataSource.new)
      ..addLazySingleton<IUserRepository>(UserRepository.new)
      ..addLazySingleton<GetUserNameCommand>(GetUserNameCommand.new)
      ..addLazySingleton<IUserClient>(() => UserClient())
      ..route(
        RouteEnum.root.path,
        child: (context, _) => DashboardScreen(
          command: inject<GetUserNameCommand>(),
          onBudgetPressed: () {},
          onMenuPressed: () => context.pushNamed(RouteEnum.settings.path),
          onExpensePressed: () => context.pushNamed(RouteEnum.expense.path),
          onNotificationsPressed: () {},
        ),
      );
  },
);
