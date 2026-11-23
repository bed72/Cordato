import 'package:cordato/features/core/infrastructure/clients/database/database_client.dart';

import 'package:cordato/features/expense/domain/enums/category_enum.dart';
import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';

final class const SuggestionResponse({
  required final int id,
  required final String description,
  required final CategoryEnum category,
  final int? amount,
}) {
  factory SuggestionResponse.fromRecord(ExpensesTableData record) {
    return SuggestionResponse(
      id: record.id,
      amount: record.amount,
      description: record.description!,
      category: CategoryEnum.fromValue(record.category),
    );
  }

  ExpenseSuggestionEntity toEntity() => ExpenseSuggestionEntity(
    id: id,
    cents: amount,
    category: category,
    description: description,
  );
}
