import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';

import 'package:cordato/features/user/infrastructure/repositories/user_repository.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/application/repositories/interface_user_repository.dart';

import 'package:cordato/features/user/presentation/screens/user/user_screen.dart';
import 'package:cordato/features/user/presentation/screens/user/bloc/user_bloc.dart';
import 'package:cordato/features/user/presentation/screens/edit/edit_user_screen.dart';
import 'package:cordato/features/user/presentation/screens/edit/bloc/edit_bloc.dart';

final userDependenciesModule = createModule(
  register: (context) =>
      context.addLazySingleton<IUserRepository>(UserRepository.new),
);

final userModule = createModule(
  path: RouteEnum.user.path,
  register: (context) => context
    ..module(userDependenciesModule)
    ..add<UserBloc>(UserBloc.new)
    ..add<EditBloc>(EditBloc.new)
    ..route(
      RouteEnum.app.path,
      child: (context, _) => UserScreen(
        bloc: inject<UserBloc>,
        onBackPressed: (context) => context.pop(),
        onNamePressed: (name) => context.pushNamed<UserEntity>(
          RouteEnum.userEdit.path,
          arguments: name,
        ),
      ),
    )
    ..route(
      '/edit',
      child: (_, state) => EditUserScreen(
        bloc: inject<EditBloc>,
        onBackPressed: (context) => context.pop(),
        initialName: state.arguments as String? ?? '',
        onUpdated: (context, user) => context.pop(user),
      ),
    ),
);
