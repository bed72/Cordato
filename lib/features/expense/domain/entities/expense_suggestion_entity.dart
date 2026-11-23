import 'package:cordato/features/expense/domain/enums/category_enum.dart';

final class ExpenseSuggestionEntity({
  required final int id,
  required final String description,
  required final CategoryEnum category,
  final int? cents,
}) {
  this {
    if (cents != null && cents! <= 0) {
      throw ArgumentError.value(cents, 'cents');
    }
  }
}
