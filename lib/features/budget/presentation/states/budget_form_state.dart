import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/budget/presentation/enums/budget_period_option_enum.dart';

final class const BudgetFormState({
  final int value = 0,
  final String? valueFailure,
  final String? periodFailure,
  final DateTimeRange? period,
  final bool isRecurring = false,
  final BudgetPeriodOptionEnum periodOption = .monthly,
}) {
  factory BudgetFormState.initial(DateTime date) {
    const option = BudgetPeriodOptionEnum.monthly;
    return BudgetFormState(
      periodOption: option,
      period: option.periodStartingAt(date),
    );
  }

  BudgetFormState copyWith({
    int? value,
    bool? isRecurring,
    String? valueFailure,
    String? periodFailure,
    DateTimeRange? period,
    bool clearValueFailure = false,
    bool clearPeriodFailure = false,
    BudgetPeriodOptionEnum? periodOption,
  }) => BudgetFormState(
    value: value ?? this.value,
    period: period ?? this.period,
    isRecurring: isRecurring ?? this.isRecurring,
    periodOption: periodOption ?? this.periodOption,
    valueFailure: clearValueFailure ? null : valueFailure ?? this.valueFailure,
    periodFailure: clearPeriodFailure
        ? null
        : periodFailure ?? this.periodFailure,
  );
}
