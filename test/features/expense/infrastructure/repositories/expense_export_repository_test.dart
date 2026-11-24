import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/database/database_client.dart';
import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/infrastructure/repositories/expense_export_repository.dart';

import '../../../../support/expense/fakes/expense_query_interceptor.dart';

void main() {
  late DatabaseClient database;
  late ExpenseExportRepository repository;
  late ExpenseQueryInterceptor interceptor;

  setUp(() {
    interceptor = ExpenseQueryInterceptor();
    database = DatabaseClient(
      executor: NativeDatabase.memory().interceptWith(interceptor),
    );
    repository = ExpenseExportRepository(client: database);
  });

  tearDown(() => database.close());

  Future<int> profile() => database
      .into(database.profilesTable)
      .insert(ProfilesTableCompanion.insert(name: 'Cordato', seed: 'private'));

  Future<int> insert({
    required int profileId,
    String date = '2026-11-24',
    String? description,
    int cents = 100,
  }) => database
      .into(database.expensesTable)
      .insert(
        ExpensesTableCompanion.insert(
          profileId: profileId,
          amount: cents,
          description: Value(description),
          occurredOn: Value(date),
        ),
      );

  test('empty database returns null without creating a profile', () async {
    expect(await repository.prepare(), isNull);
    expect(await database.select(database.profilesTable).get(), isEmpty);
  });

  test('empty profile returns null', () async {
    await profile();

    expect(await repository.prepare(), isNull);
  });

  test(
    'exports complete history in one ordered SELECT without writes',
    () async {
      final profileId = await profile();
      final later = await insert(profileId: profileId, description: 'Depois');
      final earlier = await insert(
        profileId: profileId,
        date: '2026-01-01',
        description: 'Antes',
      );
      final tied = await insert(profileId: profileId);
      for (int index = 0; index < 205; index++) {
        await insert(profileId: profileId, date: '2026-12-01');
      }
      interceptor.selects.clear();

      final bytes = await repository.prepare();
      final lines = utf8.decode(bytes!.sublist(3)).split('\r\n');

      expect(lines, hasLength(210));
      expect(lines[1], startsWith('$earlier;01/01/2026;Antes;'));
      expect(lines[2], startsWith('$later;24/11/2026;Depois;'));
      expect(lines[3], startsWith('$tied;24/11/2026;;'));
      expect(utf8.decode(bytes), isNot(contains('private')));
      expect(interceptor.selects, hasLength(1));
      expect(interceptor.selects.single, isNot(contains('LIMIT')));
      expect(interceptor.selects.single, contains('profiles'));
      expect(interceptor.writes, isEmpty);
    },
  );

  test('deleted expenses and cascaded history are not exported', () async {
    final profileId = await profile();
    await insert(profileId: profileId);
    await database.delete(database.profilesTable).go();

    expect(await repository.prepare(), isNull);
  });

  for (final failure in [
    SqliteException(extendedResultCode: 5, message: 'native database path'),
    const FileSystemException('private filesystem path'),
  ]) {
    test('translates operational ${failure.runtimeType} safely', () async {
      await profile();
      interceptor.beforeRead = () async => throw failure;

      await expectLater(
        repository.prepare(),
        throwsA(
          isA<ExpenseException>().having(
            (error) => error.errors.errors.single.detail,
            'safe detail',
            isNot(contains('path')),
          ),
        ),
      );
    });
  }

  test('unexpected failures preserve identity and stack', () async {
    await profile();
    final failure = StateError('unexpected');
    final stack = StackTrace.current;
    interceptor.beforeRead = () async =>
        Error.throwWithStackTrace(failure, stack);

    await expectLater(repository.prepare(), throwsA(same(failure)));
  });

  test('invalid category prevents offering a partial CSV', () async {
    final profileId = await profile();
    await insert(profileId: profileId);
    await database.customStatement('PRAGMA ignore_check_constraints = ON');
    await database.customStatement("UPDATE expenses SET category = 'invalid'");

    await expectLater(repository.prepare(), throwsStateError);
  });
}
