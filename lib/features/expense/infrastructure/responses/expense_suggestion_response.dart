import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';

final class const ExpenseSuggestionResponse({
  required final String id,
  required final String description,
  final int? amount,
}) {
  factory ExpenseSuggestionResponse.fromJson(Map<String, dynamic> json) {
    return ExpenseSuggestionResponse(
      id: json['id'] as String,
      amount: json['amount'] as int,
      description: json['description'] as String,
    );
  }

  ExpenseSuggestionEntity toEntity() =>
      ExpenseSuggestionEntity(id: id, description: description, cents: amount);
}
