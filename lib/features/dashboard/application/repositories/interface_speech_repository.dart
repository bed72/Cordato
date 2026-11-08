import 'package:cordato/features/dashboard/application/events/speech_update_event.dart';

abstract interface class ISpeechRepository {
  Future<void> finish({required int operation});
  Future<void> discard({required int operation});
  void confirmDiagnostic({required int operation});
  Stream<SpeechUpdateEvent> start({required int operation});
}
