import 'package:cordato/features/core/application/events/recording_event.dart';

abstract interface class IAudioRepository {
  Future<void> finish({required int operation});
  Future<void> discard({required int operation});
  Stream<RecordingEvent> start({required int operation});
}
