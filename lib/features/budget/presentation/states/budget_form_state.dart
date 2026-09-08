import 'package:material_ui/material_ui.dart';

final class BudgetFormState {
  final int value;
  final String description;
  final String? valueFailure;
  final String? periodFailure;
  final DateTimeRange? period;
  final String? descriptionFailure;

  const BudgetFormState({
    this.value = 0,
    this.period,
    this.valueFailure,
    this.periodFailure,
    this.description = '',
    this.descriptionFailure,
  });

  BudgetFormState copyWith({
    int? value,
    String? description,
    String? valueFailure,
    String? periodFailure,
    DateTimeRange? period,
    String? descriptionFailure,
    bool clearValueFailure = false,
    bool clearPeriodFailure = false,
    bool clearDescriptionFailure = false,
  }) => BudgetFormState(
    value: value ?? this.value,
    period: period ?? this.period,
    description: description ?? this.description,
    valueFailure: clearValueFailure ? null : valueFailure ?? this.valueFailure,
    periodFailure: clearPeriodFailure
        ? null
        : periodFailure ?? this.periodFailure,
    descriptionFailure: clearDescriptionFailure
        ? null
        : descriptionFailure ?? this.descriptionFailure,
  );
}
