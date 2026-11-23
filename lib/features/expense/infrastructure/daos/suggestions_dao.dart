import 'package:drift/drift.dart';

import 'package:cordato/features/core/infrastructure/clients/database/database_client.dart';

final class SuggestionsDao({required DatabaseClient client})
    extends DatabaseAccessor<DatabaseClient> {
  this : super(client);

  Future<List<ExpensesTableData>> get({required String query}) async {
    final records = await customSelect(
      '''
WITH candidates AS MATERIALIZED (
  SELECT *
  FROM expenses
  WHERE profile_id = (SELECT id FROM profiles)
    AND description IS NOT NULL
    AND description <> ''
    AND instr(cordato_lower(description), ?) > 0
  ORDER BY occurred_on DESC, id DESC
  LIMIT 30
), ranked AS (
  SELECT *,
    row_number() OVER (
      PARTITION BY cordato_lower(description)
      ORDER BY occurred_on DESC, id DESC
    ) AS occurrence
  FROM candidates
)
SELECT id, profile_id, amount, category, description, occurred_on
FROM ranked
WHERE occurrence = 1
ORDER BY occurred_on DESC, id DESC
''',
      variables: [.withString(query.toLowerCase())],
      readsFrom: {
        attachedDatabase.expensesTable,
        attachedDatabase.profilesTable,
      },
    ).get();

    return List<ExpensesTableData>.unmodifiable(
      records.map((record) => attachedDatabase.expensesTable.map(record.data)),
    );
  }
}
