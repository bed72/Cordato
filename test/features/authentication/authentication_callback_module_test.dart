import 'dart:io' hide HttpClient;

import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';
import 'package:cordato/features/authentication/domain/enums/email_status_enum.dart';

import 'package:cordato/features/authentication/authentication_module.dart';
import 'package:cordato/features/authentication/infrastructure/repositories/authentication_repository.dart';
import 'package:cordato/features/core/core_module.dart';
import 'package:cordato/features/core/application/clients/interface_session_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/session/session_module.dart';
import 'package:cordato/features/session/application/repositories/interface_session_repository.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/bloc/callback_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/bloc/callback_event.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/bloc/callback_state.dart';

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
      boot.injector.get<Dio>().httpClientAdapter = adapter;
      final authentication = boot.injector.get<IAuthenticationRepository>();
      final session = boot.injector.get<ISessionRepository>();

      expect(authentication, isA<AuthenticationRepository>());
      expect(
        boot.injector.get<IAuthenticationRepository>(),
        same(authentication),
      );
      expect(adapter.requests, isEmpty);
      final restored = session.session.first;
      expect(await session.loadSession(), isTrue);
      expect(await restored, isTrue);
      final loggedOut = session.session.first;
      await authentication.signOut();
      expect(await loggedOut, isFalse);
      expect(adapter.requests.map((request) => request.method), [
        'GET',
        'DELETE',
      ]);
    },
  );

  test('callback factories resolve the application contract without sibling routes', () async {
    final repository = AuthenticationRepositoryMock();
    when(() => repository.confirmEmail('verification-token'))
        .thenAnswer((_) async => EmailVerificationStatusEnum.success);
    final boot = bootstrapModule(
      createModule(register: (context) => context.module(authenticationModule)),
    );
    boot.injector.replaceInstance<IAuthenticationRepository>(repository);
    addTearDown(boot.injector.dispose);
    final first = boot.injector.get<CallbackBloc>();
    final second = boot.injector.get<CallbackBloc>();
    addTearDown(first.close);
    addTearDown(second.close);

    expect(first, isNot(same(second)));
    final finished = first.stream.firstWhere(
      (state) => state is CallbackSuccess,
    );
    first.add(const CallbackRequestedEvent(token: 'verification-token'));
    await finished;

    expect(second.state, isA<CallbackInitial>());
    verify(() => repository.confirmEmail('verification-token')).called(1);
  });
}
