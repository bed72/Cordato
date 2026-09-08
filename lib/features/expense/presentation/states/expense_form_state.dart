final class ExpenseFormState {
  final int value;
  final DateTime? date;
  final String description;
  final String? valueFailure;
  final String? dateFailure;
  final String? descriptionFailure;

  const ExpenseFormState({
    this.value = 0,
    this.date,
    this.description = '',
    this.valueFailure,
    this.dateFailure,
    this.descriptionFailure,
  });

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
