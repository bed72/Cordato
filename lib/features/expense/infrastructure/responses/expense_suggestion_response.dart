import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';
import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';

final class const ExpenseSuggestionResponse({
  required final String id,
  required final String description,
  required final ExpenseCategoryEnum category,
  final int? amount,
}) {
  factory ExpenseSuggestionResponse.fromJson(Map<String, dynamic> json) {
    return ExpenseSuggestionResponse(
      id: json['id'] as String,
      amount: json['amount'] as int,
      description: json['description'] as String,
      category: ExpenseCategoryEnum.values.firstWhere(
        (category) => category.value == json['category'] as String,
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
