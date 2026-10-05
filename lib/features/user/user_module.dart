import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';

import 'package:cordato/features/user/data/repositories/user_repository.dart';
import 'package:cordato/features/user/domain/repositories/interface_user_repository.dart';

import 'package:cordato/features/user/infrastructure/local/user_local_data_source.dart';
import 'package:cordato/features/user/infrastructure/remoto/user_remote_data_source.dart';

import 'package:cordato/features/user/presentation/screens/edit_user/edit_user_screen.dart';
import 'package:cordato/features/user/presentation/screens/user/user_screen.dart';

final userDependenciesModule = createModule(
  register: (ModularContext context) => context
    ..addLazySingleton<IUserRemoteDataSource>(UserRemoteDataSource.new)
    ..addLazySingleton<IUserLocalDataSource>(UserLocalDataSource.new)
    ..addLazySingleton<IUserRepository>(UserRepository.new),
);

final userRoutesModule = createModule(
  path: RouteEnum.user.path,
  register: (context) => context
    ..route(
      RouteEnum.app.path,
      child: (context, _) => UserScreen(
        name: 'Gabriel Ramos',
        email: 'gabriel@exemplo.com',
        onBackPressed: (context) => context.pop(),
        onNamePressed: () => context.pushNamed(RouteEnum.userEdit.path),
        onDeletePressed: () {},
      ),
    )
    ..route(
      '/edit',
      child: (_, _) => EditUserScreen(
        initialName: 'Gabriel Ramos',
        onBackPressed: (context) => context.pop(),
      ),
    ),
);
