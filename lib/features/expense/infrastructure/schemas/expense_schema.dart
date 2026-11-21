import 'package:tostore/tostore.dart';

import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';

final expenseSchema = TableSchema(
  name: 'expenses',
  primaryKeyConfig: const PrimaryKeyConfig(name: 'id', type: .sequential),
  fields: [
    const FieldSchema(
      name: 'amount',
      minValue: 1,
      type: .integer,
      nullable: false,
    ),
    FieldSchema(
      name: 'category',
      type: .text,
      nullable: false,
      defaultValue: ExpenseCategoryEnum.other.value,
    ),
    const FieldSchema(
      type: .datetime,
      nullable: false,
      createIndex: true,
      name: 'occurred_on',
    ),
    const FieldSchema(name: 'description', type: .text),
  ],
);
