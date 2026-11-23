import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/database/database_client.dart';
import 'package:cordato/features/metrics/infrastructure/daos/metrics_dao.dart';

import '../../../../support/metrics/fakes/metrics_query_interceptor.dart';

void main() {
  late DatabaseClient database;
  late MetricsDao dao;
  late MetricsQueryInterceptor interceptor;
  late int profileId;

  setUp(() async {
    interceptor = MetricsQueryInterceptor();
    database = DatabaseClient(
      executor: NativeDatabase.memory().interceptWith(interceptor),
    );
    dao = MetricsDao(client: database);
    profileId = await database
        .into(database.profilesTable)
        .insert(ProfilesTableCompanion.insert(name: 'Cordato', seed: 'seed'));
  });

  tearDown(() => database.close());

  Future<void> insert({
    required int amount,
    String category = 'other',
    String date = '2026-10-15',
    int? profile,
  }) async {
    await database
        .into(database.expensesTable)
        .insert(
          ExpensesTableCompanion.insert(
            profileId: profile ?? profileId,
            amount: amount,
            category: Value(category),
            occurredOn: Value(date),
          ),
        );
  }

  Future<List<ExpenseCategoryMetricsRecord>> load() =>
      dao.get(from: '2026-10-01', to: '2026-10-31');

  test('aggregates and orders categories in one parameterized query', () async {
    await insert(amount: 2);
    await insert(amount: 3, category: 'food');
    await insert(amount: 4, category: 'food');
    await insert(amount: 100, date: '2026-09-30');
    await insert(amount: 100, date: '2026-11-01');

    final records = await load();

    expect(records, [
      (category: 'food', total: 7, minimumAmount: 3),
      (category: 'other', total: 2, minimumAmount: 2),
    ]);
    expect(interceptor.selects, hasLength(1));
    expect(interceptor.selects.single, contains('GROUP BY category'));
    expect(interceptor.arguments.single, ['2026-10-01', '2026-10-31']);
    expect(() => records.clear(), throwsUnsupportedError);
  });

  test('uses the existing profile and civil date index', () async {
    await load();
    final plan = await database
        .customSelect(
          'EXPLAIN QUERY PLAN ${interceptor.selects.single}',
          variables: [
            Variable.withString('2026-10-01'),
            Variable.withString('2026-10-31'),
          ],
        )
        .get();

    expect(
      plan.map((row) => row.read<String>('detail')).join('\n'),
      contains('expenses_profile_date'),
    );
  });

  test('does not include expenses unrelated to the current profile', () async {
    await database.customStatement('PRAGMA foreign_keys = OFF');
    await insert(amount: 100, profile: profileId + 1);
    await database.customStatement('PRAGMA foreign_keys = ON');
    await insert(amount: 2);

    expect((await load()).single.total, 2);
  });

  test(
    'absent profile returns no groups and does not create a profile',
    () async {
      await database.delete(database.profilesTable).go();

      expect(await load(), isEmpty);
      expect(await database.select(database.profilesTable).get(), isEmpty);
    },
  );

  test('untrusted date input remains a bound value', () async {
    await insert(amount: 2);

    final records = await dao.get(
      from: "2026-10-01' OR 1=1 --",
      to: '2026-10-31',
    );

    expect(records.single.total, 2);
    expect(interceptor.selects.single, isNot(contains('OR 1=1')));
    expect(interceptor.arguments.single.first, "2026-10-01' OR 1=1 --");
  });
}
