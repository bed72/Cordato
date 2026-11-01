import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/authentication/authentication_module.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/bloc/callback_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/bloc/callback_event.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/bloc/callback_state.dart';

import '../../support/core/mocks/http_client_mock.dart';
import '../../support/core/mocks/storage_client_mock.dart';

void main() {
  late HttpClientMock client;
  late ModularBootstrap boot;
  late StorageClientMock storage;

  const token = 'fixture.a%2Bb.token';

  setUpAll(() => registerFallbackValue(const Requests(path: '')));

  setUp(() {
    client = HttpClientMock();
    storage = StorageClientMock();

    when(() => client.post(parameter: any(named: 'parameter')))
        .thenAnswer((_) async => const Responses(status: 204, body: {}));

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

  group('CallbackBloc bindings', () {
    test('creates independent factories using the real repository', () async {
      final first = inject<CallbackBloc>();
      final second = inject<CallbackBloc>();

      addTearDown(first.close);
      addTearDown(second.close);

      expect(first, isNot(same(second)));

      final finished = first.stream.firstWhere(
        (state) => state is CallbackSuccess,
      );

      first.add(const CallbackRequestedEvent(token: token));
      await finished;

      expect(second.state, isA<CallbackInitial>());

      final request =
          verify(() => client.post(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;

      expect(request.body, {'token': token});
      expect(request.path, 'collections/users/confirm-verification');
      verifyZeroInteractions(storage);
    });
  });
}
