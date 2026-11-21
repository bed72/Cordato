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
      final profile = await database.getValue('profile') as Map;

      expect(profile.keys, unorderedEquals(['name', 'avatar']));
      expect(profile['name'], 'Cordato');
      expect(profile['avatar'], matches(RegExp(r'^[0-9a-f]{32}$')));

      await database.close();
      database = await ToStoreFactory.create(
        directory: directory.path,
        schemas: const [],
      );
      await initializeProfile(database: database);

      expect(await database.getValue('profile'), profile);
    });

    test('preserves personalized profile on repeated initialization', () async {
      final savedProfile = await database.setValue('profile', {
        'name': 'Gabriel',
        'avatar': 'chosen-seed',
      });
      expect(savedProfile.hasErrors, isFalse);

      await initializeProfile(database: database);
      await initializeProfile(database: database);

      expect(await database.getValue('profile'), {
        'name': 'Gabriel',
        'avatar': 'chosen-seed',
      });
    });

    test('does not overwrite malformed profile', () async {
      final savedProfile = await database.setValue('profile', {
        'name': 'Cordato',
        'avatar': 123,
      });
      expect(savedProfile.hasErrors, isFalse);

      await expectLater(
        initializeProfile(database: database),
        throwsA(isA<TypeError>()),
      );

      expect(await database.getValue('profile'), {
        'name': 'Cordato',
        'avatar': 123,
      });
    });
  });

  group('initialization failures', () {
    test('rejects empty seed without overwriting the profile', () async {
      final database = ToStoreMock();
      when(() => database.getValue('profile')).thenAnswer(
        (_) async => {'name': 'Cordato', 'avatar': ''},
      );

      await expectLater(
        initializeProfile(database: database),
        throwsA(isA<FormatException>()),
      );

      verify(() => database.getValue('profile')).called(1);
      verifyNoMoreInteractions(database);
    });

    test('propagates read failure without creating a new profile', () async {
      final database = ToStoreMock();
      final failure = StateError('read failed');
      when(() => database.getValue('profile')).thenThrow(failure);

      await expectLater(
        initializeProfile(database: database),
        throwsA(same(failure)),
      );

      verify(() => database.getValue('profile')).called(1);
      verifyNoMoreInteractions(database);
    });

    test('propagates thrown write failure without retry', () async {
      final database = ToStoreMock();
      final failure = StateError('write failed');
      when(() => database.getValue('profile')).thenAnswer((_) async => null);
      when(() => database.setValue('profile', any())).thenThrow(failure);

      await expectLater(
        initializeProfile(database: database),
        throwsA(same(failure)),
      );

      verify(() => database.getValue('profile')).called(1);
      verify(() => database.setValue('profile', any())).called(1);
      verifyNoMoreInteractions(database);
    });

    test('rejects an unsuccessful write preserving native statuses', () async {
      final database = ToStoreMock();
      final statuses = [
        GeneralStatus(type: ResultType.engError, message: 'write failed'),
      ];
      when(() => database.getValue('profile')).thenAnswer((_) async => null);
      when(() => database.setValue('profile', any()))
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
