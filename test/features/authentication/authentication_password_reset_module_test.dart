import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

import 'package:cordato/features/authentication/authentication_module.dart';
import 'package:cordato/features/authentication/presentation/screens/password_recovery/bloc/password_recovery_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/password_recovery/bloc/password_recovery_event.dart';
import 'package:cordato/features/authentication/presentation/screens/password_recovery/bloc/password_recovery_state.dart';
import 'package:cordato/features/authentication/presentation/screens/reset_password/bloc/reset_password_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/reset_password/bloc/reset_password_event.dart';
import 'package:cordato/features/authentication/presentation/screens/reset_password/bloc/reset_password_state.dart';
import 'package:cordato/features/core/presentation/enums/route_enum.dart';

import '../../support/core/fakes/pocketbase_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PocketBaseFixture fixture;
  late ModularBootstrap boot;

  setUp(() {
    fixture = PocketBaseFixture();
    addTearDown(fixture.client.close);
    boot = bootstrapModule(
      createModule(
        register: (context) => context
          ..addInstance<PocketBase>(fixture.client)
          ..module(authenticationModule),
      ),
    );
    addTearDown(boot.injector.dispose);
  });

  test(
    'recovery is page-scoped and resolves the SDK repository without UI',
    () async {
      expect(
        () => boot.injector.get<PasswordRecoveryBloc>(),
        throwsA(anything),
      );
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
      addTearDown(() async {
        if (!bloc.isClosed) {
          await spec.dispose(bloc);
        }
      });
      expect(boot.injector.get<PasswordRecoveryBloc>(), same(bloc));
      final sent = bloc.stream.firstWhere(
        (state) => state is PasswordRecoverySent,
      );

      bloc.add(const PasswordRecoverySubmitted(email: 'person@example.com'));
      await sent;

      expect(
        fixture.requests.single.url.path,
        '/api/collections/users/request-password-reset',
      );
      expect(fixture.client.authStore.token, isEmpty);
      await spec.dispose(bloc);
      expect(bloc.isClosed, isTrue);
    },
  );

  test(
    'reset is page-scoped and clears the shared session before confirmation',
    () async {
      fixture.authenticate();
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
      addTearDown(() async {
        if (!bloc.isClosed) {
          await spec.dispose(bloc);
        }
      });
      final ready = bloc.stream.firstWhere(
        (state) => state is ResetPasswordReady,
      );

      bloc.add(const ResetPasswordOpened(hasToken: true));
      await ready;
      expect(fixture.client.authStore.token, isEmpty);
      expect(fixture.requests, isEmpty);
      final complete = bloc.stream.firstWhere(
        (state) => state is ResetPasswordSuccess,
      );
      bloc.add(
        const ResetPasswordSubmitted(
          token: 'reset-token',
          password: 'NewPass1',
          passwordConfirm: 'NewPass1',
        ),
      );
      await complete;

      expect(
        fixture.requests.single.url.path,
        '/api/collections/users/confirm-password-reset',
      );
      await spec.dispose(bloc);
      expect(bloc.isClosed, isTrue);
    },
  );
}
