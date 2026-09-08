final class ExpenseEntity {
  static const maxAmount = 9999999999999;

  final int amount;
  final DateTime date;
  final String description;

  const ExpenseEntity._({
    required this.date,
    required this.amount,
    required this.description,
  });

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
