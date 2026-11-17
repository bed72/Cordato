import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cordato/features/user/domain/entities/user_entity.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/user/application/repositories/interface_user_repository.dart';
import 'package:cordato/features/user/user_module.dart';
import 'package:cordato/features/user/presentation/screens/user/bloc/user_bloc.dart';
import 'package:cordato/features/user/presentation/screens/user/bloc/user_event.dart';
import 'package:cordato/features/user/presentation/screens/user/bloc/user_state.dart';
import 'package:cordato/features/user/presentation/screens/edit/bloc/edit_bloc.dart';
import 'package:cordato/features/user/presentation/screens/edit/bloc/edit_event.dart';
import 'package:cordato/features/user/presentation/screens/edit/bloc/edit_state.dart';

import '../../support/user/mocks/user_repository_mock.dart';

void main() {
  late UserRepositoryMock repository;
  late ModularBootstrap boot;

  setUp(() {
    repository = UserRepositoryMock();
    const user = UserEntity(
      id: 'user-1',
      name: 'Gabriel',
      email: 'person@example.com',
    );
    when(repository.getById).thenAnswer((_) async => user);
    when(() => repository.update(name: 'Gabriel'))
        .thenAnswer((_) async => user);
    boot = bootstrapModule(
      createModule(
        register: (context) => context
          ..addInstance<IUserRepository>(repository)
          ..module(userModule),
      ),
    );
    addTearDown(boot.injector.dispose);
  });

  test(
    'shared repository resolves without visiting the profile route',
    () async {
      final user = await boot.injector.get<IUserRepository>().getById();

      expect(boot.injector.get<IUserRepository>(), same(repository));
      expect(user.id, 'user-1');
      verify(repository.getById).called(1);
    },
  );

  test('profile factories independently load the current user', () async {
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
    expect(first, isNot(same(second)));
    final finished = first.stream.firstWhere((state) => state is UserReady);

    first.add(const UserRequestedEvent());
    await finished;

    expect(first.state.user!.name, 'Gabriel');
    expect(second.state, isA<UserInitial>());
    verify(repository.getById).called(1);
  });

  test(
    'edit factories delegate the name to the application repository',
    () async {
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
      expect(first, isNot(same(second)));
      final finished = first.stream.firstWhere((state) => state is EditSuccess);

      first.add(const EditSubmittedEvent(name: 'Gabriel'));
      await finished;

      expect(second.state, isA<EditInitial>());
      verify(() => repository.update(name: 'Gabriel')).called(1);
    },
  );
}
