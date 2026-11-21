import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tostore/tostore.dart';

import 'package:cordato/features/core/infrastructure/clients/tostore/tostore_factory.dart';
import 'package:cordato/features/user/application/exceptions/user_exception.dart';
import 'package:cordato/features/user/infrastructure/repositories/user_repository.dart';
import 'package:cordato/features/user/infrastructure/storage/profile_initializer.dart';

import '../../../../support/core/mocks/tostore_mock.dart';

void main() {
  group('Persistent local profile', () {
    late Directory directory;
    late ToStore database;
    late UserRepository repository;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('cordato-user-');
      database = await ToStoreFactory.create(
        directory: directory.path,
        schemas: const [],
      );
      await initializeProfile(database: database);
      repository = UserRepository(database: database);
    });

    tearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });

    test('reads initialized name and seed without an account', () async {
      final profile = await repository.get();

      expect(profile.name, 'Cordato');
      expect(profile.avatar, matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test(
      'reads current storage on each call without a cached profile',
      () async {
        await repository.get();
        final savedName = await database.setValue(
          'profile.name',
          'Updated externally',
        );
        final savedAvatar = await database.setValue(
          'profile.avatar',
          'external-seed',
        );
        expect(savedName.hasErrors, isFalse);
        expect(savedAvatar.hasErrors, isFalse);

        final profile = await repository.get();

        expect(profile.name, 'Updated externally');
        expect(profile.avatar, 'external-seed');
      },
    );

    test('updates name without replacing the saved avatar', () async {
      final original = await repository.get();

      final updated = await repository.update(name: '  Gabriel  ');

      expect(updated.name, '  Gabriel  ');
      expect(updated.avatar, original.avatar);
      expect((await repository.get()).name, '  Gabriel  ');
    });

    test('updates seed without replacing the saved name', () async {
      final updated = await repository.update(avatar: '  selected-seed  ');

      expect(updated.name, 'Cordato');
      expect(updated.avatar, '  selected-seed  ');
      expect((await repository.get()).avatar, '  selected-seed  ');
    });

    test('updates both supplied fields', () async {
      final updated = await repository.update(name: 'Gabriel', avatar: 'seed');

      expect(updated.name, 'Gabriel');
      expect(updated.avatar, 'seed');
      expect(await database.getValue('profile.name'), 'Gabriel');
      expect(await database.getValue('profile.avatar'), 'seed');
    });

    test('an empty update preserves the entire profile', () async {
      final original = await repository.get();

      final unchanged = await repository.update();

      expect(unchanged.name, original.name);
      expect(unchanged.avatar, original.avatar);
    });

    test('persists name and seed across close and reopen', () async {
      await repository.update(name: 'Gabriel', avatar: 'chosen-seed');
      await database.close();
      database = await ToStoreFactory.create(
        directory: directory.path,
        schemas: const [],
      );
      await initializeProfile(database: database);
      repository = UserRepository(database: database);

      final reopened = await repository.get();

      expect(reopened.name, 'Gabriel');
      expect(reopened.avatar, 'chosen-seed');
    });

    test(
      'concurrent independent repositories preserve both updated fields',
      () async {
        await Future.wait([
          repository.update(name: 'Gabriel'),
          UserRepository(database: database).update(avatar: 'chosen-seed'),
        ]);

        final profile = await repository.get();

        expect(profile.name, 'Gabriel');
        expect(profile.avatar, 'chosen-seed');
      },
    );

    test('missing profile fails without silently recreating it', () async {
      await database.removeValue('profile.name');
      await database.removeValue('profile.avatar');

      await expectLater(
        repository.get(),
        throwsA(
          isA<UserException>().having(
            (exception) => exception.errors.errors.single.code,
            'code',
            'profile_missing',
          ),
        ),
      );
      await expectLater(
        repository.update(name: 'Gabriel'),
        throwsA(isA<UserException>()),
      );

      expect(await database.getValue('profile.name'), isNull);
      expect(await database.getValue('profile.avatar'), isNull);
    });

    for (final invalidField in [
      (key: 'profile.name', value: 123),
      (key: 'profile.avatar', value: false),
      (key: 'profile.name', value: <String, dynamic>{}),
      (key: 'profile.avatar', value: <String>[]),
    ]) {
      test(
        'malformed ${invalidField.key} propagates ${invalidField.value.runtimeType}',
        () async {
          final savedProfile = await database.setValue(
            invalidField.key,
            invalidField.value,
          );
          expect(savedProfile.hasErrors, isFalse);

          await expectLater(repository.get(), throwsA(isA<TypeError>()));
          await expectLater(
            repository.update(name: 'Gabriel'),
            throwsA(isA<TypeError>()),
          );

          expect(await database.getValue(invalidField.key), invalidField.value);
        },
      );
    }
  });

  group('Injected storage failures', () {
    late ToStoreMock database;
    late UserRepository repository;

    setUp(() {
      database = ToStoreMock();
      repository = UserRepository(database: database);
      when(() => database.getValue('profile.name'))
          .thenAnswer((_) async => 'Cordato');
      when(() => database.getValue('profile.avatar'))
          .thenAnswer((_) async => 'original-seed');
    });

    for (final operation in ['read', 'update']) {
      test(
        '$operation maps native storage errors without exposing messages',
        () async {
          final statuses = [
            GeneralStatus(type: ResultType.engError, message: 'private data'),
            GeneralStatus(
              type: ResultType.sysDbClosed,
              message: 'private path',
            ),
          ];
          when(() => database.getValue('profile.name'))
              .thenThrow(DbException(statuses));

          final pendingProfile = operation == 'read'
              ? repository.get()
              : repository.update(name: 'Gabriel');

          await expectLater(
            pendingProfile,
            throwsA(
              isA<UserException>()
                  .having(
                    (exception) =>
                        exception.errors.errors.map((error) => error.code),
                    'codes',
                    statuses.map((status) => status.codeKey),
                  )
                  .having(
                    (exception) => exception.errors.errors.every(
                      (error) => error.title == null && error.detail == null,
                    ),
                    'no raw storage messages',
                    isTrue,
                  ),
            ),
          );
        },
      );

      test(
        '$operation maps filesystem failures to safe expected errors',
        () async {
          when(() => database.getValue('profile.name'))
              .thenThrow(const FileSystemException('private path'));

          await expectLater(
            operation == 'read'
                ? repository.get()
                : repository.update(name: 'Gabriel'),
            throwsA(isA<UserException>()),
          );
        },
      );
    }

    test(
      'an unsuccessful write fails and permits a later manual retry',
      () async {
        int writes = 0;
        when(() => database.setValue(any(), any()))
            .thenAnswer((invocation) async {
              writes += 1;
              if (writes == 1) {
                return DbResult(
                  statuses: [
                    GeneralStatus(
                      type: ResultType.engError,
                      message: 'write failed',
                    ),
                  ],
                );
              }
              when(() => database.getValue('profile.avatar'))
                  .thenAnswer((_) async => 'new-seed');
              return DbResult(statuses: []);
            });

        await expectLater(
          repository.update(name: 'Gabriel'),
          throwsA(isA<UserException>()),
        );
        final updated = await repository.update(avatar: 'new-seed');

        expect(updated.name, 'Cordato');
        expect(updated.avatar, 'new-seed');
        verify(() => database.setValue('profile.name', 'Gabriel')).called(1);
        verify(() => database.setValue('profile.avatar', 'new-seed')).called(1);
      },
    );

    test(
      'does not complete an update before storage acknowledges the write',
      () async {
        final writeStarted = Completer<void>();
        final pendingWrite = Completer<DbResult>();
        when(() => database.setValue('profile.name', any())).thenAnswer((_) {
          writeStarted.complete();
          return pendingWrite.future;
        });
        bool acknowledged = false;
        final updating = repository.update(name: 'Gabriel').then((profile) {
          acknowledged = true;
          return profile;
        });

        await writeStarted.future;
        expect(acknowledged, isFalse);
        when(() => database.getValue('profile.name'))
            .thenAnswer((_) async => 'Gabriel');
        pendingWrite.complete(DbResult(statuses: []));
        final updated = await updating;

        expect(acknowledged, isTrue);
        expect(updated.name, 'Gabriel');
      },
    );

    for (final failure in [
      StateError('unexpected'),
      const FormatException('invalid profile'),
    ]) {
      test(
        'unexpected ${failure.runtimeType} propagates without masking',
        () async {
          when(() => database.getValue('profile.name')).thenThrow(failure);

          await expectLater(repository.get(), throwsA(same(failure)));
          await expectLater(
            repository.update(name: 'Gabriel'),
            throwsA(same(failure)),
          );
        },
      );
    }

    test('a thrown write failure is not reported as success', () async {
      final failure = StateError('unexpected write');
      when(() => database.setValue('profile.name', any())).thenThrow(failure);

      await expectLater(
        repository.update(name: 'Gabriel'),
        throwsA(same(failure)),
      );

      verify(() => database.setValue('profile.name', any())).called(1);
    });

    test('name update writes only its own key', () async {
      when(() => database.setValue('profile.name', 'Gabriel'))
          .thenAnswer((_) async {
            when(() => database.getValue('profile.name'))
                .thenAnswer((_) async => 'Gabriel');
            return DbResult(statuses: []);
          });

      await repository.update(name: 'Gabriel');

      verify(() => database.setValue('profile.name', 'Gabriel')).called(1);
      verifyNever(() => database.setValue('profile.avatar', any()));
    });

    test(
      'a second field failure does not hide an acknowledged first write',
      () async {
        when(() => database.setValue('profile.name', 'Gabriel'))
            .thenAnswer((_) async {
              when(() => database.getValue('profile.name'))
                  .thenAnswer((_) async => 'Gabriel');
              return DbResult(statuses: []);
            });
        when(() => database.setValue('profile.avatar', 'new-seed')).thenAnswer(
          (_) async => DbResult(
            statuses: [
              GeneralStatus(type: ResultType.engError, message: 'write failed'),
            ],
          ),
        );

        await expectLater(
          repository.update(name: 'Gabriel', avatar: 'new-seed'),
          throwsA(isA<UserException>()),
        );
        final stored = await repository.get();

        expect(stored.name, 'Gabriel');
        expect(stored.avatar, 'original-seed');
        verify(() => database.setValue('profile.name', 'Gabriel')).called(1);
        verify(() => database.setValue('profile.avatar', 'new-seed')).called(1);
      },
    );

    test('native developer errors remain unexpected failures', () async {
      final failure = DbException([
        GeneralStatus(
          type: ResultType.devInvalidArgumentType,
          message: 'developer mistake',
        ),
      ]);
      when(() => database.getValue('profile.name')).thenThrow(failure);

      await expectLater(repository.get(), throwsA(same(failure)));
      await expectLater(
        repository.update(name: 'Gabriel'),
        throwsA(same(failure)),
      );
    });

    test('thrown native write failures use safe application errors', () async {
      when(() => database.setValue('profile.avatar', any())).thenThrow(
        DbException([
          GeneralStatus(type: ResultType.engError, message: 'private path'),
        ]),
      );

      await expectLater(
        repository.update(avatar: 'new-seed'),
        throwsA(isA<UserException>()),
      );

      verify(() => database.setValue('profile.avatar', any())).called(1);
    });
  });
}
