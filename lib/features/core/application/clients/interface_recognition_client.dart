import 'package:cordato/features/core/application/events/recognition_event.dart';

abstract interface class IRecognitionClient {
  Future<void> discard({required int operation});
  Future<String> finish({required int operation});
  Stream<RecognitionEvent> start({required int operation});
}
