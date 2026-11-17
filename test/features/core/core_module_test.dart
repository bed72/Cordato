import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/core_module.dart';
import 'package:cordato/features/core/application/clients/interface_recording_client.dart';
import 'package:cordato/features/core/infrastructure/clients/recording/recording_client.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

import '../../support/core/mocks/flutter_secure_storage_mock.dart';
import '../../support/core/fakes/secure_storage_channel_fake.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cordato-di-');
    addTearDown(() => directory.delete(recursive: true));
  });

  group('PocketBase initialization before DI', () {
    late FlutterSecureStorageMock storage;

    setUp(() {
      storage = FlutterSecureStorageMock();
      final channel = SecureStorageChannelFake(storage: storage);
      channel.install();
      addTearDown(channel.dispose);
    });

    test(
      'registers the same ready SDK after secure session restoration',
      () async {
        final read = Completer<String?>();
        final readStarted = Completer<void>();
        when(() => storage.read(key: '@cordato.pocketbase_auth'))
            .thenAnswer((_) {
              readStarted.complete();
              return read.future;
            });
        when(
          () => storage.write(
            key: '@cordato.pocketbase_auth',
            value: any(named: 'value'),
          ),
        ).thenAnswer((_) async {});
        addTearDown(() {
          if (!read.isCompleted) {
            read.complete();
          }
        });
        verifyZeroInteractions(storage);

        final initialization = PocketBaseFactory.create(
          url: 'https://example.com',
        );
        bool clientDelivered = false;
        final observedClient = initialization.then((client) {
          clientDelivered = true;
          addTearDown(client.close);
          return client;
        });
        await readStarted.future;
        await Future<void>.value();

        expect(clientDelivered, isFalse);
        verify(() => storage.read(key: '@cordato.pocketbase_auth')).called(1);

        read.complete(
          jsonEncode({
            'token': 'stored-token',
            'model': {'id': 'user-id', 'collectionName': 'users'},
          }),
        );
        final client = await observedClient;
        final boot = bootstrapModule(
          createModule(
            register: (context) => context
              ..addInstance<Directory>(directory)
              ..addInstance<PocketBase>(client)
              ..module(coreModule),
          ),
        );
        addTearDown(boot.injector.dispose);

        expect(clientDelivered, isTrue);
        expect(boot.injector.get<PocketBase>(), same(client));
        expect(boot.injector.get<PocketBase>(), same(client));
        expect(
          boot.injector.get<PocketBase>().authStore,
          same(client.authStore),
        );
        final formatter = boot.injector.get<IMoneyFormatter>();
        expect(boot.injector.get<IMoneyFormatter>(), same(formatter));
        final recording = boot.injector.get<IRecordingClient>();
        expect(recording, isA<RecordingClient>());
        expect(boot.injector.get<IRecordingClient>(), same(recording));
        expect(client.authStore.token, 'stored-token');
        expect(client.authStore.record?.id, 'user-id');
        verifyNever(() => storage.read(key: '@cordato.pocketbase_auth'));
      },
    );

    test(
      'propagates storage failure before the module can be composed',
      () async {
        final read = Completer<String?>();
        final failure = PlatformException(code: 'storage_unavailable');
        when(() => storage.read(key: '@cordato.pocketbase_auth'))
            .thenAnswer((_) => read.future);
        bool moduleComposed = false;
        final initialization =
            PocketBaseFactory.create(url: 'https://example.com').then((client) {
              addTearDown(client.close);
              moduleComposed = true;
              return createModule(
                register: (context) => context
                  ..addInstance<Directory>(directory)
                  ..addInstance<PocketBase>(client)
                  ..module(coreModule),
              );
            });
        final initializationFailure = expectLater(
          initialization,
          throwsA(
            isA<PlatformException>().having(
              (exception) => exception.code,
              'code',
              failure.code,
            ),
          ),
        );

        read.completeError(failure);
        await initializationFailure;

        expect(moduleComposed, isFalse);
        verify(() => storage.read(key: '@cordato.pocketbase_auth')).called(1);
      },
    );
  });
}
