import 'package:drift/drift.dart';

@TableIndex.sql('CREATE UNIQUE INDEX profiles_singleton ON profiles (1)')
class ProfilesTable extends Table {
  @override
  String get tableName => 'profiles';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get seed => text()();
}
