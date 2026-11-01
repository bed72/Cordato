import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';

import 'package:cordato/features/session/session_module.dart';
import 'package:cordato/features/session/presentation/bloc/session_bloc.dart';
import 'package:cordato/features/session/presentation/bloc/session_event.dart';
import 'package:cordato/features/session/presentation/bloc/session_state.dart';

import '../../support/core/mocks/storage_client_mock.dart';
import '../../support/core/mocks/http_client_mock.dart';

void main() {
  setUpAll(() => registerFallbackValue(const Requests(path: '')));
  test(
    'registers independent Bloc factories over the HTTP and storage repository',
    () async {
      final storage = StorageClientMock();
      final http = HttpClientMock();
      final changes = StreamController<String?>.broadcast();
      when(() => storage.watch(key: StorageKeyEnum.token.key))
          .thenAnswer((_) => changes.stream);
      when(() => storage.read(key: StorageKeyEnum.token.key))
          .thenAnswer((_) async => 'opaque-token');
      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(() => http.post(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Responses(
          status: 200,
          body: {
            'token': 'refreshed-token',
            'record': {'id': 'fixture-user'},
          },
        ),
      );
      final boot = bootstrapModule(
        createModule(
          register: (context) {
            context.addInstance<IStorageClient>(storage);
            context.addInstance<IHttpClient>(http);
            context.module(sessionModule);
          },
        ),
      );
      final first = inject<SessionBloc>();
      final second = inject<SessionBloc>();
      addTearDown(() async {
        await first.close();
        await second.close();
        await changes.close();
        boot.injector.dispose();
      });
      expect(first, isNot(same(second)));
      final ready = first.stream.firstWhere(
        (state) => state is SessionAuthenticated,
      );
      first.add(const SessionStartedEvent());
      await ready;
      expect(second.state, isA<SessionInitial>());
      verify(() => storage.read(key: StorageKeyEnum.token.key)).called(3);
      verify(
        () => storage.write(
          key: StorageKeyEnum.token.key,
          value: 'refreshed-token',
        ),
      ).called(1);
      verify(
        () => storage.write(
          key: StorageKeyEnum.userId.key,
          value: 'fixture-user',
        ),
      ).called(1);
      final request =
          verify(() => http.post(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(request.path, 'collections/users/auth-refresh');
      expect(request.body, isNull);
      expect(request.headers, isNull);
      verify(() => storage.watch(key: StorageKeyEnum.token.key)).called(1);
      verifyNoMoreInteractions(storage);
      await first.close();
      expect(changes.hasListener, isFalse);
    },
  );
}
