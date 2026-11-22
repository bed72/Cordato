import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/user/application/exceptions/user_exception.dart';
import 'package:cordato/features/user/infrastructure/repositories/user_repository.dart';

import '../../../../support/core/mocks/collection_ref_mock.dart';
import '../../../../support/core/mocks/document_ref_mock.dart';
import '../../../../support/core/mocks/localstore_mock.dart';
import '../../../../support/core/storage/localstore_test_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Localstore profile', () {
    final storage = LocalstoreTestStorage();
    late UserRepository repository;

    setUpAll(storage.open);
    tearDownAll(storage.close);
    setUp(() async {
      await storage.initialize();
      repository = UserRepository(database: storage.database);
    });
    tearDown(storage.clear);

    test('creates and persists the default profile on first read', () async {
      final profile = await repository.get();
      final stored = jsonDecode(
        await File('${storage.directory.path}/user/profile').readAsString(),
      );

      expect(profile.name, 'Cordato');
      expect(profile.avatar, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(stored, {'name': 'Cordato', 'avatar': profile.avatar});
    });

    test('repeated reads preserve the saved avatar seed', () async {
      final original = await repository.get();
      final reloaded = await UserRepository(database: storage.database).get();

      expect(reloaded.name, original.name);
      expect(reloaded.avatar, original.avatar);
    });

    test('reads changes made through the injected SDK', () async {
      await storage.writing({'External name'}, () async {
        await storage.database.collection('user').doc('profile').set({
          'name': 'External name',
          'avatar': 'external-seed',
        });
      });

      final profile = await repository.get();

      expect(profile.name, 'External name');
      expect(profile.avatar, 'external-seed');
    });

    test('updates name without normalizing or replacing avatar', () async {
      final original = await repository.get();
      final updated = await storage.writing({
        '  Gabriel  ',
      }, () => repository.update(name: '  Gabriel  '));

      expect(updated.name, '  Gabriel  ');
      expect(updated.avatar, original.avatar);
    });

    test('updates avatar without normalizing or replacing name', () async {
      final updated = await storage.writing({
        '  selected-seed  ',
      }, () => repository.update(avatar: '  selected-seed  '));

      expect(updated.name, 'Cordato');
      expect(updated.avatar, '  selected-seed  ');
    });

    test('persists both fields in one profile document', () async {
      await storage.writing({
        'Gabriel',
        'chosen-seed',
      }, () => repository.update(name: 'Gabriel', avatar: 'chosen-seed'));
      final stored = jsonDecode(
        await File('${storage.directory.path}/user/profile').readAsString(),
      );
      final reloaded = await UserRepository(database: storage.database).get();

      expect(stored, {'name': 'Gabriel', 'avatar': 'chosen-seed'});
      expect(reloaded.name, 'Gabriel');
      expect(reloaded.avatar, 'chosen-seed');
    });

    test('empty update preserves both fields', () async {
      final original = await repository.get();
      final unchanged = await repository.update();

      expect(unchanged.name, original.name);
      expect(unchanged.avatar, original.avatar);
    });

    for (final field in ['name', 'avatar']) {
      test(
        'malformed $field propagates without replacing the profile',
        () async {
          await storage.writing({123}, () async {
            await storage.database.collection('user').doc('profile').set({
              'name': 'Cordato',
              'avatar': 'seed',
              field: 123,
            });
          });

          await expectLater(repository.get(), throwsA(isA<TypeError>()));
          await expectLater(
            repository.update(name: 'Gabriel'),
            throwsA(isA<TypeError>()),
          );
          final stored = await storage.database
              .collection('user')
              .doc('profile')
              .get();
          expect(stored![field], 123);
        },
      );
    }

    test('preserves empty avatar when updating only name', () async {
      await storage.writing({''}, () async {
        await storage.database.collection('user').doc('profile').set({
          'name': 'Cordato',
          'avatar': '',
        });
      });

      final updated = await storage.writing({
        'Gabriel',
      }, () => repository.update(name: 'Gabriel'));

      expect(updated.name, 'Gabriel');
      expect(updated.avatar, '');
    });
  });

  group('SDK delegation and failures', () {
    late LocalstoreMock database;
    late DocumentRefMock document;
    late UserRepository repository;

    setUp(() {
      database = LocalstoreMock();
      final collection = CollectionRefMock();
      document = DocumentRefMock();
      when(() => database.collection('user')).thenReturn(collection);
      when(() => collection.doc('profile')).thenReturn(document);
      when(() => document.get())
          .thenAnswer((_) async => {'name': 'Cordato', 'avatar': 'seed'});
      repository = UserRepository(database: database);
    });

    test('creates defaults only when the profile document is absent', () async {
      when(() => document.get()).thenAnswer((_) async => null);
      when(() => document.set(any())).thenAnswer((_) async {});

      final profile = await repository.get();

      expect(profile.name, 'Cordato');
      expect(profile.avatar, matches(RegExp(r'^[0-9a-f]{32}$')));
      verify(() => document.set({'name': 'Cordato', 'avatar': profile.avatar}))
          .called(1);
    });

    test('existing profile does not trigger initialization writes', () async {
      await repository.get();

      verifyNever(() => document.set(any()));
    });

    test(
      'update can create an absent profile before applying changes',
      () async {
        when(() => document.get()).thenAnswer((_) async => null);
        when(() => document.set(any())).thenAnswer((_) async {});

        final updated = await repository.update(name: 'Gabriel');

        expect(updated.name, 'Gabriel');
        expect(updated.avatar, matches(RegExp(r'^[0-9a-f]{32}$')));
        verify(() => document.set(any())).called(2);
      },
    );

    test('name update preserves avatar in the single document', () async {
      when(() => document.set(any())).thenAnswer((_) async {});

      final updated = await repository.update(name: 'Gabriel');

      expect(updated.name, 'Gabriel');
      expect(updated.avatar, 'seed');
      verify(() => document.set({'name': 'Gabriel', 'avatar': 'seed'}))
          .called(1);
    });

    test('empty update reads without writing', () async {
      await repository.update();

      verifyNever(() => document.set(any()));
    });

    test('name update preserves an absent avatar', () async {
      when(() => document.get())
          .thenAnswer((_) async => {'name': 'Cordato', 'avatar': null});
      when(() => document.set(any())).thenAnswer((_) async {});

      final updated = await repository.update(name: 'Gabriel');

      expect(updated.avatar, isNull);
      verify(() => document.set({'name': 'Gabriel', 'avatar': null})).called(1);
    });

    for (final operation in ['read', 'update']) {
      test('$operation maps exposed filesystem failure safely', () async {
        when(() => document.get())
            .thenThrow(const FileSystemException('private diagnostic'));

        await expectLater(
          operation == 'read'
              ? repository.get()
              : repository.update(name: 'Gabriel'),
          throwsA(isA<UserException>()),
        );
        verifyNever(() => document.set(any()));
      });
    }

    for (final failure in [
      StateError('unexpected'),
      const FormatException('invalid profile'),
    ]) {
      test('propagates unexpected ${failure.runtimeType}', () async {
        when(() => document.get()).thenThrow(failure);

        await expectLater(repository.get(), throwsA(same(failure)));
        await expectLater(
          repository.update(name: 'Gabriel'),
          throwsA(same(failure)),
        );
        verifyNever(() => document.set(any()));
      });
    }

    test('awaits the SDK Future when creating the default profile', () async {
      when(() => document.get()).thenAnswer((_) async => null);
      final started = Completer<void>();
      final pendingWrite = Completer<void>();
      when(() => document.set(any())).thenAnswer((_) {
        started.complete();
        return pendingWrite.future;
      });
      bool completed = false;
      final reading = repository.get().then((profile) {
        completed = true;
        return profile;
      });

      await started.future;
      expect(completed, isFalse);
      pendingWrite.complete();
      expect((await reading).name, 'Cordato');
      expect(completed, isTrue);
    });

    test('awaits the SDK Future when updating the profile', () async {
      final started = Completer<void>();
      final pendingWrite = Completer<void>();
      when(() => document.set(any())).thenAnswer((_) {
        started.complete();
        return pendingWrite.future;
      });
      bool completed = false;
      final updating = repository.update(name: 'Gabriel').then((profile) {
        completed = true;
        return profile;
      });

      await started.future;
      expect(completed, isFalse);
      pendingWrite.complete();
      expect((await updating).name, 'Gabriel');
      expect(completed, isTrue);
    });

    test(
      'exposed initialization write failure is not returned as success',
      () async {
        when(() => document.get()).thenAnswer((_) async => null);
        when(() => document.set(any()))
            .thenThrow(const FileSystemException('private path'));

        await expectLater(repository.get(), throwsA(isA<UserException>()));
        verify(() => document.set(any())).called(1);
      },
    );

    test('exposed update failure allows manual retry', () async {
      when(() => document.set(any()))
          .thenThrow(const FileSystemException('private path'));
      await expectLater(
        repository.update(name: 'Gabriel'),
        throwsA(isA<UserException>()),
      );
      when(() => document.set(any())).thenAnswer((_) async {});

      expect((await repository.update(name: 'Gabriel')).name, 'Gabriel');
      verify(() => document.set({'name': 'Gabriel', 'avatar': 'seed'}))
          .called(2);
    });

    test('unexpected write failures propagate', () async {
      final failure = StateError('unexpected write');
      when(() => document.set(any())).thenThrow(failure);

      await expectLater(
        repository.update(name: 'Gabriel'),
        throwsA(same(failure)),
      );
    });
  });
}
