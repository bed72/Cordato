import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/user/application/repositories/interface_user_repository.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';

import 'package:cordato/features/user/user_module.dart';

import 'package:cordato/features/user/presentation/screens/user/bloc/user_bloc.dart';
import 'package:cordato/features/user/presentation/screens/user/bloc/user_event.dart';
import 'package:cordato/features/user/presentation/screens/user/bloc/user_state.dart';
import 'package:cordato/features/user/presentation/screens/edit/bloc/edit_bloc.dart';
import 'package:cordato/features/user/presentation/screens/edit/bloc/edit_event.dart';
import 'package:cordato/features/user/presentation/screens/edit/bloc/edit_state.dart';

import '../../support/core/mocks/http_client_mock.dart';
import '../../support/core/mocks/storage_client_mock.dart';

void main() {
  late HttpClientMock http;
  late ModularBootstrap boot;
  late StorageClientMock storage;

  setUpAll(() => registerFallbackValue(const Requests(path: '')));

  setUp(() {
    http = HttpClientMock();
    storage = StorageClientMock();
    when(() => storage.read(key: StorageKeyEnum.userId.key))
        .thenAnswer((_) async => 'user12345678901');
    const response = Responses(
      status: 200,
      body: {
        'id': 'user12345678901',
        'avatar': '',
        'name': 'Gabriel',
        'email': 'person@example.com',
      },
    );
    when(() => http.get(parameter: any(named: 'parameter')))
        .thenAnswer((_) async => response);
    when(() => http.patch(parameter: any(named: 'parameter')))
        .thenAnswer((_) async => response);
    boot = bootstrapModule(
      createModule(
        register: (context) {
          context
            ..addInstance<IHttpClient>(http)
            ..addInstance<IStorageClient>(storage)
            ..module(userModule);
        },
      ),
    );
  });

  tearDown(() => boot.injector.dispose());

  test('shared repository resolves without visiting the profile route', () {
    expect(boot.injector.get<IUserRepository>(), isA<IUserRepository>());
  });

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
      final request =
          verify(() => http.get(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(request.path, 'collections/users/records/user12345678901');
    },
  );

  test(
    'edit factories use the real repository with a plain JSON payload',
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
      final request =
          verify(() => http.patch(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(request.path, 'collections/users/records/user12345678901');
      expect(request.body, {'name': 'Gabriel'});
    },
  );
}
