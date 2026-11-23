import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' show Database, AllowedArgumentCount;

import 'package:cordato/features/core/infrastructure/clients/database/tables/expenses_table.dart';
import 'package:cordato/features/core/infrastructure/clients/database/tables/profiles_table.dart';

part 'database_client.g.dart';

@DriftDatabase(tables: [ProfilesTable, ExpensesTable])
final class DatabaseClient extends _$DatabaseClient {
  DatabaseClient({QueryExecutor? executor}) : super(executor ?? _connection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static void configureConnection(Database database) {
    database.createFunction(
      deterministic: true,
      functionName: 'cordato_lower',
      argumentCount: const AllowedArgumentCount(1),
      function: (arguments) => (arguments.single as String?)?.toLowerCase(),
    );
  }

  static QueryExecutor _connection() => LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();
    final file = File(path.join(directory.path, 'cordato.sqlite'));

    await directory.create(recursive: true);

    return NativeDatabase.createInBackground(file, setup: configureConnection);
  });
}
