import 'package:drift/drift.dart';

import 'package:cordato/features/core/infrastructure/clients/database/tables/profiles_table.dart';

@TableIndex(
  name: 'expenses_profile_date',
  columns: {#profileId, #occurredOn, #id},
)
class ExpensesTable extends Table {
  @override
  String get tableName => 'expenses';

  TextColumn get id => text().check(id.length.isBiggerThanValue(0))();
  TextColumn get profileId =>
      text().references(ProfilesTable, #id, onDelete: .cascade)();
  IntColumn get amount => integer().customConstraint(
    "NOT NULL CHECK (typeof(amount) = 'integer' AND amount > 0)",
  )();
  TextColumn get category => text()
      .withDefault(const Constant('other'))
      .check(category.length.isBiggerThanValue(0))();
  TextColumn get description => text().nullable()();
  TextColumn get occurredOn => text().customConstraint(
    "NOT NULL CHECK (length(occurred_on) = 10 "
    "AND occurred_on >= '0001-01-01' AND occurred_on <= '9999-12-31' "
    "AND date(occurred_on, '+0 days') IS NOT NULL "
    "AND date(occurred_on, '+0 days') = occurred_on)",
  )();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
