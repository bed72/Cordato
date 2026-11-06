import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:pocketbase/pocketbase.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/user/application/repositories/interface_user_repository.dart';
import 'package:cordato/features/user/user_module.dart';
import 'package:cordato/features/user/presentation/screens/user/bloc/user_bloc.dart';
import 'package:cordato/features/user/presentation/screens/user/bloc/user_event.dart';
import 'package:cordato/features/user/presentation/screens/user/bloc/user_state.dart';
import 'package:cordato/features/user/presentation/screens/edit/bloc/edit_bloc.dart';
import 'package:cordato/features/user/presentation/screens/edit/bloc/edit_event.dart';
import 'package:cordato/features/user/presentation/screens/edit/bloc/edit_state.dart';

import '../../support/core/fakes/pocketbase_fixture.dart';

void main() {
  late PocketBaseFixture fixture;
  late ModularBootstrap boot;

  setUp(() {
    fixture = PocketBaseFixture();
    fixture.authenticate();
    fixture.respond = (_) => PocketBaseFixture.jsonResponse({
      'id': 'user-1',
      'collectionName': 'users',
      'avatar': '',
      'name': 'Gabriel',
      'email': 'person@example.com',
    });
    boot = bootstrapModule(
      createModule(
        register: (context) => context
          ..addInstance<PocketBase>(fixture.client)
          ..module(userModule),
      ),
    );
    addTearDown(fixture.client.close);
    addTearDown(boot.injector.dispose);
  });

  test(
    'shared repository resolves without visiting the profile route',
    () async {
      final repository = boot.injector.get<IUserRepository>();

      final user = await repository.getById();

      expect(boot.injector.get<IUserRepository>(), same(repository));
      expect(user.id, 'user-1');
      expect(
        fixture.requests.single.headers['Authorization'],
        PocketBaseFixture.token,
      );
    },
  );

  test(
    'profile factories independently load native PocketBase records',
    () async {
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
      expect(fixture.requests.single.method, 'GET');
      expect(
        fixture.requests.single.url.path,
        '/api/collections/users/records/user-1',
      );
    },
  );

  test('edit factories use the real SDK repository with plain JSON', () async {
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
    final request = fixture.requests.single;
    expect(request.method, 'PATCH');
    expect(request.url.path, '/api/collections/users/records/user-1');
    expect(jsonDecode(request.body), {'name': 'Gabriel'});
    expect(fixture.client.authStore.record?.data['name'], 'Gabriel');
  });
}
