import 'dart:convert';

import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

import 'package:cordato/features/authentication/authentication_module.dart';
import 'package:cordato/features/authentication/presentation/validators/password_validation.dart';
import 'package:cordato/features/authentication/presentation/screens/change_password/bloc/change_password_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/change_password/bloc/change_password_event.dart';
import 'package:cordato/features/authentication/presentation/screens/change_password/bloc/change_password_state.dart';
import 'package:cordato/features/core/presentation/enums/route_enum.dart';

import '../../support/core/fakes/pocketbase_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('change password stays protected and page-owned using the SDK and local sign-out', () async {
    final fixture = PocketBaseFixture();
    fixture.authenticate();
    fixture.respond = (_) => PocketBaseFixture.jsonResponse({'id': 'user-1'});
    addTearDown(fixture.client.close);
    final boot = bootstrapModule(
      createModule(
        register: (context) => context
          ..addInstance<PocketBase>(fixture.client)
          ..module(authenticationModule),
      ),
    );
    addTearDown(boot.injector.dispose);

    expect(
      RouteEnum.authenticatedPaths(),
      contains(RouteEnum.authenticationChangePassword.path),
    );
    expect(() => boot.injector.get<ChangePasswordBloc>(), throwsA(anything));
    expect(boot.injector.get<PasswordValidation>(), isA<PasswordValidation>());
    final route = boot.routes.routes.singleWhere(
      (route) => route.path == RouteEnum.authenticationChangePassword.path,
    );
    final scope = Scoped();
    route.provide!(scope);
    expect(scope.specs.map((spec) => spec.type), [ChangePasswordBloc]);
    final spec = scope.specs.single;
    boot.injector.uncommit();
    spec.register(boot.injector);
    boot.injector.commit();
    final bloc = spec.resolve(boot.injector) as ChangePasswordBloc;
    addTearDown(() async {
      if (!bloc.isClosed) {
        await spec.dispose(bloc);
      }
    });
    expect(boot.injector.get<ChangePasswordBloc>(), same(bloc));
    final complete = bloc.stream.firstWhere(
      (state) => state is ChangePasswordSuccess,
    );

    bloc.add(
      const ChangePasswordSubmitted(
        oldPassword: 'OldPass1',
        password: 'NewPass1',
        passwordConfirm: 'NewPass1',
      ),
    );
    await complete;

    expect(fixture.client.authStore.token, isEmpty);
    final request = fixture.requests.single;
    expect(request.url.path, '/api/collections/users/records/user-1');
    expect(jsonDecode(request.body), {
      'oldPassword': 'OldPass1',
      'password': 'NewPass1',
      'passwordConfirm': 'NewPass1',
    });
    await spec.dispose(bloc);
    expect(bloc.isClosed, isTrue);
  });
}
