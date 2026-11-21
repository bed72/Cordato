import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tostore/tostore.dart';

import 'package:cordato/features/core/infrastructure/clients/tostore/tostore_factory.dart';
import 'package:cordato/features/user/infrastructure/storage/profile_initializer.dart';

import '../../../../support/core/mocks/tostore_mock.dart';

void main() {
  group('persistent profile', () {
    late Directory directory;
    late ToStore database;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('cordato-profile-');
      database = await ToStoreFactory.create(
        directory: directory.path,
        schemas: const [],
      );
    });

    tearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });

    test('creates a profile without ID and persists a random seed', () async {
      await initializeProfile(database: database);
      final seed = await database.getValue('profile.avatar');

      expect(await database.getValue('profile.name'), 'Cordato');
      expect(seed, matches(RegExp(r'^[0-9a-f]{32}$')));

      await database.close();
      database = await ToStoreFactory.create(
        directory: directory.path,
        schemas: const [],
      );
      await initializeProfile(database: database);

      expect(await database.getValue('profile.name'), 'Cordato');
      expect(await database.getValue('profile.avatar'), seed);
    });

    test('preserves personalized profile on repeated initialization', () async {
      final savedName = await database.setValue('profile.name', 'Gabriel');
      final savedAvatar = await database.setValue(
        'profile.avatar',
        'chosen-seed',
      );
      expect(savedName.hasErrors, isFalse);
      expect(savedAvatar.hasErrors, isFalse);

      await initializeProfile(database: database);
      await initializeProfile(database: database);

      expect(await database.getValue('profile.name'), 'Gabriel');
      expect(await database.getValue('profile.avatar'), 'chosen-seed');
    });

    test('does not overwrite malformed profile', () async {
      final savedName = await database.setValue('profile.name', 'Cordato');
      final savedAvatar = await database.setValue('profile.avatar', 123);
      expect(savedName.hasErrors, isFalse);
      expect(savedAvatar.hasErrors, isFalse);

      await expectLater(
        initializeProfile(database: database),
        throwsA(isA<TypeError>()),
      );

      expect(await database.getValue('profile.name'), 'Cordato');
      expect(await database.getValue('profile.avatar'), 123);
    });

    test(
      'initializes an absent seed without overwriting the existing name',
      () async {
        final savedName = await database.setValue('profile.name', 'Gabriel');
        expect(savedName.hasErrors, isFalse);

        await initializeProfile(database: database);

        expect(await database.getValue('profile.name'), 'Gabriel');
        expect(
          await database.getValue('profile.avatar'),
          matches(RegExp(r'^[0-9a-f]{32}$')),
        );
      },
    );

    test(
      'initializes an absent name without changing the existing seed',
      () async {
        final savedAvatar = await database.setValue(
          'profile.avatar',
          'chosen-seed',
        );
        expect(savedAvatar.hasErrors, isFalse);

        await initializeProfile(database: database);

        expect(await database.getValue('profile.name'), 'Cordato');
        expect(await database.getValue('profile.avatar'), 'chosen-seed');
      },
    );
  });

  group('initialization failures', () {
    test('rejects empty seed without overwriting the profile', () async {
      final database = ToStoreMock();
      when(() => database.getValue('profile.name'))
          .thenAnswer((_) async => 'Cordato');
      when(() => database.getValue('profile.avatar'))
          .thenAnswer((_) async => '');

      await expectLater(
        initializeProfile(database: database),
        throwsA(isA<FormatException>()),
      );

      verify(() => database.getValue('profile.name')).called(1);
      verify(() => database.getValue('profile.avatar')).called(1);
      verifyNoMoreInteractions(database);
    });

    test('propagates read failure without creating a new profile', () async {
      final database = ToStoreMock();
      final failure = StateError('read failed');
      when(() => database.getValue('profile.name')).thenThrow(failure);

      await expectLater(
        initializeProfile(database: database),
        throwsA(same(failure)),
      );

      verify(() => database.getValue('profile.name')).called(1);
      verifyNoMoreInteractions(database);
    });

    test('propagates thrown write failure without retry', () async {
      final database = ToStoreMock();
      final failure = StateError('write failed');
      when(() => database.getValue(any())).thenAnswer((_) async => null);
      when(() => database.setValue('profile.name', any())).thenThrow(failure);

      await expectLater(
        initializeProfile(database: database),
        throwsA(same(failure)),
      );

      verify(() => database.getValue('profile.name')).called(1);
      verify(() => database.getValue('profile.avatar')).called(1);
      verify(() => database.setValue('profile.name', any())).called(1);
      verifyNoMoreInteractions(database);
    });

    test('rejects an unsuccessful write preserving native statuses', () async {
      final database = ToStoreMock();
      final statuses = [
        GeneralStatus(type: ResultType.engError, message: 'write failed'),
      ];
      when(() => database.getValue(any())).thenAnswer((_) async => null);
      when(() => database.setValue('profile.name', any()))
          .thenAnswer((_) async => DbResult(statuses: statuses));

      await expectLater(
        initializeProfile(database: database),
        throwsA(
          isA<DbException>().having(
            (exception) => exception.statuses,
            'statuses',
            same(statuses),
          ),
        ),
      );
    });
  });
}
