import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:tostore/tostore.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/tostore/tostore_factory.dart';
import 'package:cordato/features/user/user_module.dart';
import 'package:cordato/features/user/infrastructure/storage/profile_initializer.dart';
import 'package:cordato/features/user/application/repositories/interface_user_repository.dart';
import 'package:cordato/features/user/presentation/screens/user/bloc/user_bloc.dart';
import 'package:cordato/features/user/presentation/screens/user/bloc/user_event.dart';
import 'package:cordato/features/user/presentation/screens/user/bloc/user_state.dart';
import 'package:cordato/features/user/presentation/screens/edit/bloc/edit_bloc.dart';
import 'package:cordato/features/user/presentation/screens/edit/bloc/edit_event.dart';
import 'package:cordato/features/user/presentation/screens/edit/bloc/edit_state.dart';

void main() {
  late Directory directory;
  late ToStore database;
  late ModularBootstrap boot;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cordato-user-module-');
    database = await ToStoreFactory.create(
      directory: directory.path,
      schemas: const [],
    );
    await initializeProfile(database: database);
    boot = bootstrapModule(
      createModule(
        register: (context) => context
          ..addInstance<ToStore>(database)
          ..module(userModule),
      ),
    );
  });

  tearDown(() async {
    boot.injector.dispose();
    await database.close();
    await directory.delete(recursive: true);
  });

  test(
    'shared repository resolves without visiting the profile route',
    () async {
      final repository = boot.injector.get<IUserRepository>();

      final profile = await repository.get();

      expect(boot.injector.get<IUserRepository>(), same(repository));
      expect(profile.name, 'Cordato');
      expect(profile.avatar, isNotEmpty);
    },
  );

  test('profile factories independently load local data', () async {
    final route = boot.routes.routes.singleWhere(
      (route) => route.path == RouteEnum.user.path,
    );
    boot.manager.enter('profile', route.ownerTags);
    final first = boot.injector.get<UserBloc>();
    final second = boot.injector.get<UserBloc>();
    addTearDown(() async {
      await first.close();
      await second.close();
      boot.manager.leave('profile', route.ownerTags);
    });
    final finished = first.stream.firstWhere((state) => state is UserReady);

    first.add(const UserRequestedEvent());
    await finished;

    expect(first, isNot(same(second)));
    expect(first.state.user!.name, 'Cordato');
    expect(second.state, isA<UserInitial>());
  });

  test('edit factories persist through the shared local repository', () async {
    final route = boot.routes.routes.singleWhere(
      (route) => route.path == RouteEnum.userEdit.path,
    );
    boot.manager.enter('edit', route.ownerTags);
    final first = boot.injector.get<EditBloc>();
    final second = boot.injector.get<EditBloc>();
    addTearDown(() async {
      await first.close();
      await second.close();
      boot.manager.leave('edit', route.ownerTags);
    });
    final repository = boot.injector.get<IUserRepository>();
    final original = await repository.get();
    final finished = first.stream.firstWhere((state) => state is EditSuccess);

    first.add(const EditSubmittedEvent(name: 'Gabriel'));
    await finished;
    final saved = await repository.get();

    expect(first, isNot(same(second)));
    expect(second.state, isA<EditInitial>());
    expect(saved.name, 'Gabriel');
    expect(saved.avatar, original.avatar);
  });

  test('registers only the two local profile destinations', () {
    expect(RouteEnum.user.authenticated, isFalse);
    expect(RouteEnum.userEdit.authenticated, isFalse);
    expect(
      boot.routes.routes.map((route) => route.path),
      unorderedEquals([RouteEnum.user.path, RouteEnum.userEdit.path]),
    );
  });

  test(
    'leaving User keeps its repository available to other consumers',
    () async {
      final repository = boot.injector.get<IUserRepository>();
      final route = boot.routes.routes.singleWhere(
        (route) => route.path == RouteEnum.user.path,
      );

      boot.manager.enter('profile', route.ownerTags);
      await repository.update(name: 'Gabriel');
      boot.manager.leave('profile', route.ownerTags);
      final sharedRepository = boot.injector.get<IUserRepository>();
      final profile = await sharedRepository.get();

      expect(sharedRepository, same(repository));
      expect(profile.name, 'Gabriel');
    },
  );
}
