import 'package:cordato/features/dashboard/application/enums/speech_failure_enum.dart';

sealed class const SpeechState() {
  int? get operation => null;
  bool get expanded =>
      this is SpeechPreparing ||
      this is SpeechListening ||
      this is SpeechReady ||
      this is SpeechFinalizing;
  bool get canCancel =>
      this is SpeechPreparing || this is SpeechListening || this is SpeechReady;
  bool get canSubmit => this is SpeechListening || this is SpeechReady;
}

final class const SpeechIdle() extends SpeechState;

final class const SpeechPreparing({@override required final int operation})
    extends SpeechState;

final class SpeechListening({
  @override required final int operation,
  List<double> levels = const [],
}) extends SpeechState {
  final List<double> levels = List.unmodifiable(levels);
}

final class const SpeechReady({@override required final int operation})
    extends SpeechState;

final class const SpeechFinalizing({@override required final int operation})
    extends SpeechState;

final class const SpeechCollapsing({
  @override required final int operation,
  final bool confirmed = false,
  final SpeechFailureEnum? failure,
}) extends SpeechState;
