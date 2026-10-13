import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';

import 'package:cordato/features/user/application/repositories/user_repository.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/domain/repositories/interface_user_repository.dart';

import 'package:cordato/features/user/infrastructure/local/user_local_data_source.dart';
import 'package:cordato/features/user/infrastructure/remoto/user_remote_data_source.dart';

import 'package:cordato/features/user/presentation/screens/user/user_screen.dart';
import 'package:cordato/features/user/presentation/screens/user/commands/user_command.dart';
import 'package:cordato/features/user/presentation/screens/edit_user/edit_user_screen.dart';
import 'package:cordato/features/user/presentation/screens/user/commands/delete_user_command.dart';
import 'package:cordato/features/user/presentation/screens/user/commands/update_avatar_command.dart';
import 'package:cordato/features/user/presentation/screens/edit_user/commands/update_user_command.dart';

final userDependenciesModule = createModule(
  register: (ModularContext context) => context
    ..addLazySingleton<IUserLocalDataSource>(UserLocalDataSource.new)
    ..addLazySingleton<IUserRemoteDataSource>(UserRemoteDataSource.new)
    ..addLazySingleton<IUserRepository>(UserRepository.new)
    ..add<UserCommand>(UserCommand.new),
);

final userRoutesModule = createModule(
  path: RouteEnum.user.path,
  register: (context) => context
    ..addLazySingleton<DeleteUserCommand>(DeleteUserCommand.new)
    ..addLazySingleton<UpdateUserCommand>(UpdateUserCommand.new)
    ..add<UpdateAvatarCommand>(UpdateAvatarCommand.new)
    ..route(
      RouteEnum.app.path,
      child: (context, _) => UserScreen(
        command: inject<UserCommand>(),
        onBackPressed: (context) => context.pop(),
        deleteCommand: inject<DeleteUserCommand>(),
        avatarCommand: inject<UpdateAvatarCommand>(),
        onNamePressed: (name) => context.pushNamed<UserEntity>(
          RouteEnum.userEdit.path,
          arguments: name,
        ),
      ),
    )
    ..route(
      '/edit',
      child: (_, state) => EditUserScreen(
        command: inject<UpdateUserCommand>(),
        onBackPressed: (context) => context.pop(),
        initialName: state.arguments as String? ?? '',
        onUpdated: (context, user) => context.pop(user),
      ),
    ),
);
