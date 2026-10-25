final class const AmountValueObject._({required final int cents}) {
  static AmountValueObject create({required int cents}) {
    if (cents <= 0) {
      throw ArgumentError.value(
        cents,
        'cents',
        'O valor da despesa deve ser maior que zero.',
      );
    }

    return AmountValueObject._(cents: cents);
  }

  @override
  int get hashCode => cents.hashCode;

  @override
  bool operator ==(Object other) =>
      other is AmountValueObject && cents == other.cents;
}
