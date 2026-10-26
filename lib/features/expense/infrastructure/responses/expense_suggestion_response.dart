import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';

final class const ExpenseSuggestionResponse({
  required final String id,
  required final String description,
  final int? amount,
}) {
  factory ExpenseSuggestionResponse.fromJson(Map<String, dynamic> json) {
    final root = json['attributes'] as Map<String, dynamic>;

    return ExpenseSuggestionResponse(
      id: json['id'] as String,
      amount: root['amount'] as int?,
      description: root['description'] as String,
    );
  }

  ExpenseSuggestionEntity toEntity() =>
      ExpenseSuggestionEntity(id: id, description: description, cents: amount);
}
