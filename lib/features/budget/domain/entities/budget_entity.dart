final class BudgetEntity {
  static const maxAmount = 9999999999999;

  final int amount;
  final DateTime endDate;
  final DateTime startDate;
  final String? description;

  const BudgetEntity._({
    required this.amount,
    required this.endDate,
    required this.startDate,
    required this.description,
  });

  static BudgetEntity? create({
    required int amount,
    required DateTime endDate,
    required DateTime startDate,
    required String description,
  }) {
    final normalizedEndDate = _dateOnly(endDate);
    final normalizedStartDate = _dateOnly(startDate);
    final normalizedDescription = description.isEmpty
        ? null
        : description.trim();

    if (amount < 1 || amount > maxAmount) return null;
    if (normalizedEndDate.isBefore(normalizedStartDate)) return null;
    if (normalizedDescription != null &&
        (normalizedDescription.runes.length < 2 ||
            normalizedDescription.runes.length > 256)) {
      return null;
    }

    return BudgetEntity._(
      amount: amount,
      endDate: normalizedEndDate,
      startDate: normalizedStartDate,
      description: normalizedDescription,
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
