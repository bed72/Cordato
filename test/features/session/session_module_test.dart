import 'dart:async';

import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';
import 'package:cordato/features/session/session_module.dart';
import 'package:cordato/features/session/presentation/bloc/session_bloc.dart';
import 'package:cordato/features/session/presentation/bloc/session_event.dart';
import 'package:cordato/features/session/presentation/bloc/session_state.dart';

import '../../support/core/mocks/storage_client_mock.dart';

void main() {
  test(
    'registers independent Bloc factories over the storage-backed repository',
    () async {
      final storage = StorageClientMock();
      final changes = StreamController<String?>.broadcast();
      when(() => storage.watch(key: StorageKeyEnum.opaqueToken.key))
          .thenAnswer((_) => changes.stream);
      when(() => storage.read(key: StorageKeyEnum.opaqueToken.key))
          .thenAnswer((_) async => 'opaque-token');
      final boot = bootstrapModule(
        createModule(
          register: (context) {
            context.addInstance<IStorageClient>(storage);
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
      verify(() => storage.read(key: StorageKeyEnum.opaqueToken.key)).called(1);
      verify(() => storage.watch(key: StorageKeyEnum.opaqueToken.key))
          .called(1);
      verifyNoMoreInteractions(storage);
      await first.close();
      expect(changes.hasListener, isFalse);
    },
  );
}
