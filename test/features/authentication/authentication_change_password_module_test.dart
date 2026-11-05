import 'dart:async';

import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cordato/features/authentication/authentication_module.dart';
import 'package:cordato/features/authentication/presentation/validators/password_validation.dart';
import 'package:cordato/features/authentication/presentation/screens/change_password/bloc/change_password_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/change_password/bloc/change_password_event.dart';
import 'package:cordato/features/authentication/presentation/screens/change_password/bloc/change_password_state.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';
import 'package:cordato/features/core/presentation/enums/route_enum.dart';

import '../../support/core/mocks/http_client_mock.dart';
import '../../support/core/mocks/storage_client_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ModularBootstrap boot;
  late HttpClientMock client;
  late StorageClientMock storage;
  setUpAll(() => registerFallbackValue(const Requests(path: '')));
  setUp(() {
    client = HttpClientMock();
    storage = StorageClientMock();
    when(() => client.patch(parameter: any(named: 'parameter')))
        .thenAnswer((_) async => const Responses(status: 200, body: {}));
    when(() => storage.read(key: StorageKeyEnum.userId.key))
        .thenAnswer((_) async => 'user-1');
    when(() => storage.clear()).thenAnswer((_) async {});
    boot = bootstrapModule(
      createModule(
        register: (context) {
          context
            ..addInstance<IHttpClient>(client)
            ..addInstance<IStorageClient>(storage)
            ..module(authenticationModule);
        },
      ),
    );
  });
  tearDown(() => boot.injector.dispose());

  test('route is protected, page-owned and resolves without visiting another feature', () async {
    expect(
      RouteEnum.authenticationChangePassword.path,
      '/authentication/change-password',
    );
    expect(
      RouteEnum.authenticatedPaths(),
      contains(RouteEnum.authenticationChangePassword.path),
    );
    expect(() => boot.injector.get<ChangePasswordBloc>(), throwsA(anything));
    expect(boot.injector.get<PasswordValidation>(), isA<PasswordValidation>());
    final route = boot.routes.routes.singleWhere(
      (r) => r.path == RouteEnum.authenticationChangePassword.path,
    );
    final scope = Scoped();
    route.provide!(scope);
    expect(scope.specs.map((s) => s.type), [ChangePasswordBloc]);
    final spec = scope.specs.single;
    boot.injector.uncommit();
    spec.register(boot.injector);
    boot.injector.commit();
    final bloc = spec.resolve(boot.injector) as ChangePasswordBloc;
    expect(boot.injector.get<ChangePasswordBloc>(), same(bloc));
    final clear = Completer<void>();
    final clearing = Completer<void>();
    when(() => storage.clear()).thenAnswer((_) {
      clearing.complete();
      return clear.future;
    });
    bloc.add(
      const ChangePasswordSubmitted(
        oldPassword: 'OldPass1',
        password: 'NewPass1',
        passwordConfirm: 'NewPass1',
      ),
    );
    await clearing.future;
    expect(bloc.state, isA<ChangePasswordSigningOut>());
    final complete = bloc.stream.firstWhere((s) => s is ChangePasswordSuccess);
    clear.complete();
    await complete;
    final request =
        verify(() => client.patch(parameter: captureAny(named: 'parameter')))
                .captured
                .single
            as Requests;
    expect(request.path, 'collections/users/records/user-1');
    verify(() => storage.clear()).called(1);
    await spec.dispose(bloc);
    expect(bloc.isClosed, isTrue);
  });
}
