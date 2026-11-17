import 'dart:io' hide HttpClient;

import 'package:dio/dio.dart';
import 'package:bloc/bloc.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';

import 'package:cordato/features/authentication/authentication_module.dart';
import 'package:cordato/features/authentication/infrastructure/repositories/authentication_repository.dart';
import 'package:cordato/features/core/core_module.dart';
import 'package:cordato/features/core/application/clients/interface_session_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/session/session_module.dart';
import 'package:cordato/features/session/application/repositories/interface_session_repository.dart';
import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/code/bloc/code_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_bloc.dart';

import '../../support/authentication/mocks/authentication_repository_mock.dart';
import '../../support/core/fakes/http_client_adapter_fake.dart';

void main() {
  test(
    'production authentication and session share core outside route scopes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'cordato-auth-di-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final boot = bootstrapModule(
        createModule(
          register: (context) => context
            ..addInstance<Directory>(directory)
            ..module(coreModule)
            ..module(authenticationModule)
            ..module(sessionModule),
        ),
      );
      addTearDown(boot.injector.dispose);
      final http = boot.injector.get<IHttpClient>();
      final coordinator = boot.injector.get<ISessionClient>();
      addTearDown(() => http.close(force: true));
      addTearDown(coordinator.close);
      final adapter = HttpClientAdapterFake();
      adapter.respond = (request) {
        if (request.uri.path.endsWith('/tokens/email')) {
          return ResponseBody.fromString(
            '{"userId":"service-user"}',
            201,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        if (request.uri.path.endsWith('/sessions/token')) {
          return ResponseBody.fromString(
            '{}',
            201,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
              HttpHeaders.setCookieHeader: [
                'a_session_$projectId=fake-session; Path=/; Secure; HttpOnly',
              ],
            },
          );
        }
        if (request.method == 'DELETE') {
          return ResponseBody.fromString(
            '',
            204,
            headers: {
              HttpHeaders.setCookieHeader: [
                'a_session_$projectId=; Path=/; Max-Age=0',
              ],
            },
          );
        }
        return ResponseBody.fromString(
          '{}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };
      boot.injector.get<Dio>().httpClientAdapter = adapter;
      final authentication = boot.injector.get<IAuthenticationRepository>();
      final session = boot.injector.get<ISessionRepository>();

      expect(authentication, isA<AuthenticationRepository>());
      expect(
        boot.injector.get<IAuthenticationRepository>(),
        same(authentication),
      );
      expect(adapter.requests, isEmpty);
      final changes = <bool>[];
      final subscription = session.session.listen(changes.add);
      addTearDown(subscription.cancel);
      final userId = await authentication.requestCode(
        email: 'person@example.com',
      );
      expect(userId, 'service-user');
      expect(changes, isEmpty);
      final confirmed = session.session.first;
      await authentication.confirmCode(userId: userId, code: '012345');
      expect(await confirmed, isTrue);
      expect(
        adapter.requests.last.headers[HttpHeaders.cookieHeader],
        contains('a_session_$projectId=fake-session'),
      );
      final restored = session.session.first;
      expect(await session.loadSession(), isTrue);
      expect(await restored, isTrue);
      final loggedOut = session.session.first;
      await authentication.signOut();
      expect(await loggedOut, isFalse);
      expect(adapter.requests.map((request) => request.method), [
        'POST',
        'POST',
        'GET',
        'GET',
        'DELETE',
      ]);
      expect(changes, [true, true, false]);
      expect(
        await boot.injector.get<PersistCookieJar>().loadForRequest(
          Uri.parse('$endpoint/account'),
        ),
        isEmpty,
      );
    },
  );

  test(
    'only email and code routes exist and their Blocs belong to page scopes',
    () async {
      final repository = AuthenticationRepositoryMock();
      final boot = bootstrapModule(
        createModule(
          register: (context) => context.module(authenticationModule),
        ),
      );
      boot.injector.replaceInstance<IAuthenticationRepository>(repository);
      addTearDown(boot.injector.dispose);
      expect(boot.routes.routes.map((route) => route.path), [
        RouteEnum.authenticationSignIn.path,
        RouteEnum.authenticationConfirm.path,
      ]);
      expect(() => boot.injector.get<SignInBloc>(), throwsA(anything));
      expect(() => boot.injector.get<CodeBloc>(), throwsA(anything));
      expect(() => boot.injector.get<ResendEmailBloc>(), throwsA(anything));
      for (final route in boot.routes.routes) {
        expect(route.ownerTags, isEmpty);
        final scope = Scoped();
        route.provide!(scope);
        final expectedTypes = route.path == RouteEnum.authenticationSignIn.path
            ? [SignInBloc]
            : [CodeBloc, ResendEmailBloc];
        expect(scope.specs.map((spec) => spec.type), expectedTypes);
        boot.injector.uncommit();
        for (final spec in scope.specs) {
          spec.register(boot.injector);
        }
        boot.injector.commit();
        for (final spec in scope.specs) {
          final bloc = spec.resolve(boot.injector);
          await spec.dispose(bloc);
          expect((bloc as BlocBase<Object?>).isClosed, isTrue);
        }
      }
    },
  );
}
