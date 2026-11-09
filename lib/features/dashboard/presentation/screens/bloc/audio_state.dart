import 'package:cordato/features/dashboard/application/enums/audio_failure_enum.dart';

sealed class const AudioState() {
  int? get operation => null;
  bool get expanded =>
      this is AudioPreparing ||
      this is AudioListening ||
      this is AudioReady ||
      this is AudioFinalizing;
  bool get canCancel =>
      this is AudioPreparing || this is AudioListening || this is AudioReady;
  bool get canSubmit => this is AudioListening || this is AudioReady;
}

final class const AudioIdle() extends AudioState;

final class const AudioPreparing({@override required final int operation})
    extends AudioState;

final class AudioListening({
  @override required final int operation,
  List<double> levels = const [],
}) extends AudioState {
  final List<double> levels = List.unmodifiable(levels);
}

final class const AudioReady({@override required final int operation})
    extends AudioState;

final class const AudioFinalizing({@override required final int operation})
    extends AudioState;

final class const AudioCollapsing({
  @override required final int operation,
  final AudioFailureEnum? failure,
}) extends AudioState;
