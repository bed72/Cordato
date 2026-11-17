sealed class CodeEvent {
  const CodeEvent();
}

final class const CodeSubmittedEvent({
  required final String code,
  required final String userId,
}) extends CodeEvent {}
