import 'package:cordato/features/expense/infrastructure/responses/expense_response.dart';

final class ExpensePageResponse({
  required final String? next,
  required final String? prev,
  required List<ExpenseResponse> items,
}) {
  final List<ExpenseResponse> items = List.unmodifiable(items);

  factory ExpensePageResponse.fromJson(Map<String, dynamic> json) {
    final data = json['items'] as List<dynamic>;
    final page = json['page'] as int;
    final totalPages = json['totalPages'] as int;

    return ExpensePageResponse(
      next: page < totalPages ? '?page=${page + 1}' : null,
      prev: page > 1 ? '?page=${page - 1}' : null,
      items: data
          .map((item) => ExpenseResponse.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
