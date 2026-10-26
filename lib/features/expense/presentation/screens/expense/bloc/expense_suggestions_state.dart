import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';

sealed class ExpenseSuggestionsState {
  const ExpenseSuggestionsState({required this.revision});

  final int revision;
}

final class const ExpenseSuggestionsIdle({super.revision = 0})
    extends ExpenseSuggestionsState;

final class const ExpenseSuggestionsLoading({required super.revision})
    extends ExpenseSuggestionsState;

final class ExpenseSuggestionsSuccess({
  required super.revision,
  required List<ExpenseSuggestionEntity> suggestions,
}) extends ExpenseSuggestionsState {
  final List<ExpenseSuggestionEntity> suggestions = List.unmodifiable(
    suggestions,
  );
}

final class const ExpenseSuggestionsFailure({
  required super.revision,
  required final ErrorsEntity errors,
}) extends ExpenseSuggestionsState;
