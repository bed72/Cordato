import 'package:tostore/tostore.dart';

import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';

final expenseSchema = TableSchema(
  name: 'expenses',
  primaryKeyConfig: const PrimaryKeyConfig(
    name: 'id',
    type: PrimaryKeyType.sequential,
  ),
  fields: [
    const FieldSchema(
      name: 'amount',
      type: DataType.integer,
      nullable: false,
      minValue: 1,
    ),
    FieldSchema(
      name: 'category',
      type: DataType.text,
      nullable: false,
      defaultValue: ExpenseCategoryEnum.other.value,
    ),
    const FieldSchema(name: 'description', type: DataType.text),
    const FieldSchema(
      name: 'occurred_on',
      type: DataType.datetime,
      nullable: false,
      createIndex: true,
    ),
  ],
);
