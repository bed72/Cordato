final class CreateExpenseInput({
  required final int cents,
  required final String description,
  DateTime? occurredOn,
}) {
  final DateTime occurredOn = occurredOn ?? .now();
}
