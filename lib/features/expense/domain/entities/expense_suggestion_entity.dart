import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';

final class ExpenseSuggestionEntity({
  required final String id,
  required final String description,
  required final ExpenseCategoryEnum category,
  final int? cents,
}) {
  this {
    if (cents != null && cents! <= 0) {
      throw ArgumentError.value(cents, 'cents');
    }
  }
}
