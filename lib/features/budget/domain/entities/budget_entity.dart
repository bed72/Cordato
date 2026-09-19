final class const BudgetEntity._({
  required final int amount,
  required final DateTime endDate,
  required final DateTime startDate,
}) {
  static const maxAmount = 9999999999999;

  static BudgetEntity? create({
    required int amount,
    required DateTime endDate,
    required DateTime startDate,
  }) {
    final normalizedEndDate = _dateOnly(endDate);
    final normalizedStartDate = _dateOnly(startDate);

    if (amount < 1 || amount > maxAmount) return null;
    if (normalizedEndDate.isBefore(normalizedStartDate)) return null;

    return BudgetEntity._(
      amount: amount,
      endDate: normalizedEndDate,
      startDate: normalizedStartDate,
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
