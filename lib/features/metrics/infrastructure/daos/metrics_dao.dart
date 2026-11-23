import 'package:drift/drift.dart';

import 'package:cordato/features/core/infrastructure/clients/database/database_client.dart';

typedef ExpenseCategoryMetricsRecord = ({
  int total,
  String category,
  int minimumAmount,
});

final class MetricsDao({required DatabaseClient client})
    extends DatabaseAccessor<DatabaseClient> {
  this : super(client);

  Future<List<ExpenseCategoryMetricsRecord>> get({
    required String to,
    required String from,
  }) async {
    final records = await customSelect(
      '''
SELECT category, SUM(amount) AS total, MIN(amount) AS minimum_amount
FROM expenses
WHERE profile_id = (SELECT id FROM profiles)
  AND occurred_on >= ?
  AND occurred_on <= ?
GROUP BY category
ORDER BY category
''',
      variables: [.withString(from), .withString(to)],
      readsFrom: {
        attachedDatabase.expensesTable,
        attachedDatabase.profilesTable,
      },
    ).get();

    return List<ExpenseCategoryMetricsRecord>.unmodifiable(
      records.map(
        (record) => (
          total: record.read<int>('total'),
          category: record.read<String>('category'),
          minimumAmount: record.read<int>('minimum_amount'),
        ),
      ),
    );
  }
}
