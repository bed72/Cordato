import 'package:cordato/features/core/infrastructure/clients/database/database_client.dart';
import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';
import 'package:cordato/features/expense/domain/enums/category_enum.dart';

final class const ExpenseSuggestionResponse({
  required final int id,
  required final String description,
  required final CategoryEnum category,
  final int? amount,
}) {
  factory ExpenseSuggestionResponse.fromRecord(ExpensesTableData record) {
    return ExpenseSuggestionResponse(
      id: record.id,
      amount: record.amount,
      description: record.description!,
      category: CategoryEnum.values.firstWhere(
        (category) => category.value == record.category,
      ),
    );
  }

  ExpenseSuggestionEntity toEntity() => ExpenseSuggestionEntity(
    id: id,
    cents: amount,
    category: category,
    description: description,
  );
}
