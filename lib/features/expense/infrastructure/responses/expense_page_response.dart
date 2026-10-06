import 'package:cordato/features/expense/infrastructure/responses/expense_response.dart';

final class ExpensePageResponse({
  required final String? next,
  required final String? prev,
  required List<ExpenseResponse> items,
}) {
  final List<ExpenseResponse> items = List.unmodifiable(items);

  factory ExpensePageResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as List<dynamic>;
    final links = json['links'] as Map<String, dynamic>;

    return ExpensePageResponse(
      next: links['next'] as String?,
      prev: links['prev'] as String?,
      items: data
          .map(
            (item) => ExpenseResponse.fromJson({
              'data': item as Map<String, dynamic>,
            }),
          )
          .toList(),
    );
  }
}
