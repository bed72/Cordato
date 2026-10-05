import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/user/data/repositories/user_repository.dart';
import 'package:cordato/features/user/domain/repositories/interface_user_repository.dart';
import 'package:cordato/features/user/infrastructure/local/user_local_data_source.dart';
import 'package:cordato/features/user/infrastructure/remoto/user_remote_data_source.dart';

final userDependenciesModule = createModule(
  register: (ModularContext context) => context
    ..addLazySingleton<IUserRemoteDataSource>(UserRemoteDataSource.new)
    ..addLazySingleton<IUserLocalDataSource>(UserLocalDataSource.new)
    ..addLazySingleton<IUserRepository>(UserRepository.new),
);
