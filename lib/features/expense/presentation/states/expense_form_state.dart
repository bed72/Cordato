final class const ExpenseFormState({
  final int value = 0,
  final DateTime? date,
  final String description = '',
  final String? valueFailure,
  final String? dateFailure,
  final String? descriptionFailure,
}) {
  ExpenseFormState copyWith({
    int? value,
    DateTime? date,
    String? description,
    String? valueFailure,
    String? dateFailure,
    String? descriptionFailure,
    bool clearValueFailure = false,
    bool clearDateFailure = false,
    bool clearDescriptionFailure = false,
  }) => ExpenseFormState(
    value: value ?? this.value,
    date: date ?? this.date,
    description: description ?? this.description,
    valueFailure: clearValueFailure ? null : valueFailure ?? this.valueFailure,
    dateFailure: clearDateFailure ? null : dateFailure ?? this.dateFailure,
    descriptionFailure: clearDescriptionFailure
        ? null
        : descriptionFailure ?? this.descriptionFailure,
  );
}
