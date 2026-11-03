import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/authentication_module.dart';
import 'package:cordato/features/authentication/presentation/screens/password_recovery/bloc/password_recovery_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/password_recovery/bloc/password_recovery_event.dart';
import 'package:cordato/features/authentication/presentation/screens/password_recovery/bloc/password_recovery_state.dart';
import 'package:cordato/features/authentication/presentation/screens/reset_password/bloc/reset_password_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/reset_password/bloc/reset_password_event.dart';
import 'package:cordato/features/authentication/presentation/screens/reset_password/bloc/reset_password_state.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
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
    when(() => client.post(parameter: any(named: 'parameter')))
        .thenAnswer((_) async => const Responses(status: 204, body: {}));
    when(() => storage.clear()).thenAnswer((_) async {});
    boot = bootstrapModule(
      createModule(
        register: (context) {
          context
            ..addInstance<IHttpClient>(client)
            ..addInstance<IStorageClient>(storage);
          context.module(authenticationModule);
        },
      ),
    );
  });
  tearDown(() => boot.injector.dispose());

  test('recovery is page-scoped and resolves the native repository without mounting UI', () async {
    expect(() => boot.injector.get<PasswordRecoveryBloc>(), throwsA(anything));
    final route = boot.routes.routes.singleWhere(
      (route) => route.path == RouteEnum.authenticationPasswordRecovery.path,
    );
    final scope = Scoped();
    route.provide!(scope);
    expect(scope.specs.map((spec) => spec.type), [PasswordRecoveryBloc]);
    final spec = scope.specs.single;
    boot.injector.uncommit();
    spec.register(boot.injector);
    boot.injector.commit();
    final bloc = spec.resolve(boot.injector) as PasswordRecoveryBloc;
    expect(boot.injector.get<PasswordRecoveryBloc>(), same(bloc));
    final sent = bloc.stream.firstWhere(
      (state) => state is PasswordRecoverySent,
    );
    bloc.add(const PasswordRecoverySubmitted(email: 'person@example.com'));
    await sent;
    final request =
        verify(() => client.post(parameter: captureAny(named: 'parameter')))
                .captured
                .single
            as Requests;
    expect(request.path, 'collections/users/request-password-reset');
    verifyZeroInteractions(storage);
    await spec.dispose(bloc);
    expect(bloc.isClosed, isTrue);
  });

  test('reset is page-scoped and clears storage before native confirmation without mounting UI', () async {
    expect(() => boot.injector.get<ResetPasswordBloc>(), throwsA(anything));
    final route = boot.routes.routes.singleWhere(
      (route) => route.path == RouteEnum.authenticationResetPassword.path,
    );
    final scope = Scoped();
    route.provide!(scope);
    expect(scope.specs.map((spec) => spec.type), [ResetPasswordBloc]);
    final spec = scope.specs.single;
    boot.injector.uncommit();
    spec.register(boot.injector);
    boot.injector.commit();
    final bloc = spec.resolve(boot.injector) as ResetPasswordBloc;
    final ready = bloc.stream.firstWhere(
      (state) => state is ResetPasswordReady,
    );
    bloc.add(const ResetPasswordOpened(hasToken: true));
    await ready;
    verify(() => storage.clear()).called(1);
    final completed = bloc.stream.firstWhere(
      (state) => state is ResetPasswordSuccess,
    );
    bloc.add(
      const ResetPasswordSubmitted(
        token: 'fixture.reset.token',
        password: 'NewPass1',
        passwordConfirm: 'NewPass1',
      ),
    );
    await completed;
    final request =
        verify(() => client.post(parameter: captureAny(named: 'parameter')))
                .captured
                .single
            as Requests;
    expect(request.path, 'collections/users/confirm-password-reset');
    verifyNoMoreInteractions(storage);
    await spec.dispose(bloc);
    expect(bloc.isClosed, isTrue);
  });
}
