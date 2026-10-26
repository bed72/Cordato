final class ExpenseSuggestionEntity({
  required final String id,
  required final String description,
  final int? cents,
}) {
  this {
    if (cents != null && cents! <= 0) {
      throw ArgumentError.value(cents, 'cents');
    }
  }
}
