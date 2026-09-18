final class const ExpenseEntity._({
  required final DateTime date,
  required final int amount,
  required final String description,
}) {
  static const maxAmount = 9999999999999;

  static ExpenseEntity? create({
    required int amount,
    required DateTime date,
    required String description,
  }) {
    final normalizedDescription = description.trim();

    if (amount < 1 || amount > maxAmount) return null;
    if (normalizedDescription.runes.length < 2 ||
        normalizedDescription.runes.length > 128) {
      return null;
    }

    return ExpenseEntity._(
      amount: amount,
      description: normalizedDescription,
      date: DateTime(date.year, date.month, date.day),
    );
  }
}
