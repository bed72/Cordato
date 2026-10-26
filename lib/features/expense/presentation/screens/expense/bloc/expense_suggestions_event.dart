sealed class ExpenseSuggestionsEvent {
  const ExpenseSuggestionsEvent({required this.revision});

  final int revision;
}

final class const ExpenseSuggestionsRequested({
  required super.revision,
  required final String query,
}) extends ExpenseSuggestionsEvent;

final class const ExpenseSuggestionsInvalidated({required super.revision})
    extends ExpenseSuggestionsEvent;
