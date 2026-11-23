import 'package:drift/drift.dart';

@TableIndex.sql('CREATE UNIQUE INDEX profiles_singleton ON profiles (1)')
class ProfilesTable extends Table {
  @override
  String get tableName => 'profiles';

  TextColumn get id => text().check(id.length.isBiggerThanValue(0))();
  TextColumn get name => text()();
  TextColumn get seed => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
